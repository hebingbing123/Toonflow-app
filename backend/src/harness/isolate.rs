//! 进程隔离的 Harness 工具。
//!
//! 通过隐藏子命令启动相同二进制文件，使白名单工具逻辑在 API 进程外运行（地址空间边界），
//! 作为 vm2 风格的替代路径。
//! 并发数由 `HARNESS_ISOLATE_MAX_CONCURRENT` 限制（默认 4），防止并行 `isolated.echo` 调用耗尽进程/文件描述符。
//!
//! **可观测**：进入并发槽队列深度、Semaphore 等待时间、子进程执行耗时见 `observe::harness_isolate_invoke_finished`，
//! 聚合统计见 [`metrics_snapshot`]（WP‑D）。
//!
//! 可选 **`HARNESS_ISOLATE_RUNNER_EXE`**：显式指定承担 `__harness_isolate_echo__` 子进程的二进制路径（默认为
//! [`std::env::current_exe`]）。集成测试使用该变量指向 **`CARGO_BIN_EXE_toonflow-server`**。

use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::LazyLock;
use std::time::Duration;
use std::time::Instant;

use serde_json::Value;
use tokio::io::AsyncWriteExt;
use tokio::process::Command;
use tokio::sync::Semaphore;

use super::invoke::InvokeError;
use super::observe;

#[inline]
fn parse_isolate_max_slots() -> usize {
    std::env::var("HARNESS_ISOLATE_MAX_CONCURRENT")
        .ok()
        .and_then(|s| s.parse::<usize>().ok())
        .filter(|&n| n > 0)
        .unwrap_or(4)
}

static ISOLATE_MAX_SLOTS: LazyLock<usize> = LazyLock::new(parse_isolate_max_slots);

static ISOLATE_SLOTS: LazyLock<Semaphore> = LazyLock::new(|| Semaphore::new(*ISOLATE_MAX_SLOTS));

struct IsolateCounters {
    /// 正在等待 Semaphore permit 的 invoke 数量（在进入 `acquire` 前置 +1，`acquire` 返回后 −1）。
    wait_queue_depth: AtomicUsize,
    /// 已取得槽并开始子进程逻辑的调用次数。
    total_invocations: AtomicU64,
    /// 取得槽之前 Semaphore 上的等待毫秒累计（用于推导平均排队等待）。
    total_semaphore_wait_ms: AtomicU64,
    total_child_spawns: AtomicU64,
    /// 预留：isolate worker 常驻池命中次数（尚无池时为 0，见 WP‑D 预热/回收）。
    total_process_reuse_hits: AtomicU64,
}

impl IsolateCounters {
    const fn new() -> Self {
        Self {
            wait_queue_depth: AtomicUsize::new(0),
            total_invocations: AtomicU64::new(0),
            total_semaphore_wait_ms: AtomicU64::new(0),
            total_child_spawns: AtomicU64::new(0),
            total_process_reuse_hits: AtomicU64::new(0),
        }
    }

    #[inline]
    fn begin_waiting_for_slot(&self) -> usize {
        self.wait_queue_depth.fetch_add(1, Ordering::SeqCst)
    }

    #[inline]
    fn end_waiting_for_slot(&self) {
        self.wait_queue_depth.fetch_sub(1, Ordering::SeqCst);
    }

    #[inline]
    fn record_slot_acquired(&self, semaphore_wait_ms: u64) {
        self.total_invocations.fetch_add(1, Ordering::Relaxed);
        self.total_semaphore_wait_ms
            .fetch_add(semaphore_wait_ms, Ordering::Relaxed);
    }

    #[inline]
    fn record_child_spawn_ok(&self) {
        self.total_child_spawns.fetch_add(1, Ordering::Relaxed);
    }
}

static ISOLATE_COUNTERS: LazyLock<IsolateCounters> = LazyLock::new(IsolateCounters::new);

/// 可被 `/ready` / 运维刮取或调试使用的瞬时隔离执行指标（进程池落地前仍为「spawn 每条一次」）。
#[derive(Clone, Debug)]
pub struct IsolateMetricsSnapshot {
    pub max_slots: usize,
    /// 当前卡在 Semaphore `acquire` 上的 invoke 近似数量。
    pub queue_depth_waiting: usize,
    /// `acquire` 时刻 `Semaphore::available_permits()` 快照（与并发交错时仅作近似）。
    pub available_permits_snapshot: usize,
    pub total_invocations: u64,
    pub total_semaphore_wait_ms: u64,
    pub total_child_spawns: u64,
    /// Worker 进程复用次数；当前无常驻池时为 0。
    pub total_process_reuse_hits: u64,
}

impl IsolateMetricsSnapshot {
    pub fn avg_semaphore_wait_ms(&self) -> f64 {
        let n = self.total_invocations;
        if n == 0 {
            0.0
        } else {
            self.total_semaphore_wait_ms as f64 / n as f64
        }
    }
}

#[must_use]
pub fn metrics_snapshot() -> IsolateMetricsSnapshot {
    IsolateMetricsSnapshot {
        max_slots: *ISOLATE_MAX_SLOTS,
        queue_depth_waiting: ISOLATE_COUNTERS.wait_queue_depth.load(Ordering::SeqCst),
        available_permits_snapshot: ISOLATE_SLOTS.available_permits(),
        total_invocations: ISOLATE_COUNTERS.total_invocations.load(Ordering::Relaxed),
        total_semaphore_wait_ms: ISOLATE_COUNTERS
            .total_semaphore_wait_ms
            .load(Ordering::Relaxed),
        total_child_spawns: ISOLATE_COUNTERS.total_child_spawns.load(Ordering::Relaxed),
        total_process_reuse_hits: ISOLATE_COUNTERS
            .total_process_reuse_hits
            .load(Ordering::Relaxed),
    }
}

fn resolve_isolate_runner_exe() -> Result<PathBuf, InvokeError> {
    if let Ok(p) = std::env::var("HARNESS_ISOLATE_RUNNER_EXE") {
        let p = p.trim();
        if !p.is_empty() {
            return Ok(PathBuf::from(p));
        }
    }
    std::env::current_exe().map_err(|e| InvokeError::IsolationFailed(format!("current_exe: {e}")))
}

/// Child entry: read JSON from stdin, write the same JSON to stdout (echo). Used by `isolated.echo`.
pub fn stdio_echo_child() -> ! {
    let mut buf = Vec::new();
    if let Err(e) = std::io::Read::read_to_end(&mut std::io::stdin(), &mut buf) {
        eprintln!("harness isolate: stdin: {e}");
        std::process::exit(1);
    }
    let v: Value = match serde_json::from_slice(&buf) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("harness isolate: json: {e}");
            std::process::exit(1);
        }
    };
    let s = match serde_json::to_string(&v) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("harness isolate: serialize: {e}");
            std::process::exit(1);
        }
    };
    println!("{s}");
    std::process::exit(0);
}

/// Run a trivial JSON echo in a child process (same semantics as `echo`, but out-of-process).
pub async fn isolated_echo(arguments: &Value) -> Result<Value, InvokeError> {
    let queued_ahead = ISOLATE_COUNTERS.begin_waiting_for_slot();
    let wait_started = Instant::now();

    let _permit = ISOLATE_SLOTS
        .acquire()
        .await
        .map_err(|_| InvokeError::IsolationFailed("isolate pool shut down".into()))?;

    ISOLATE_COUNTERS.end_waiting_for_slot();
    let semaphore_wait_ms = wait_started.elapsed().as_millis() as u64;
    ISOLATE_COUNTERS.record_slot_acquired(semaphore_wait_ms);

    let exe = resolve_isolate_runner_exe()?;

    let payload = serde_json::to_string(arguments)
        .map_err(|e| InvokeError::IsolationFailed(format!("serialize arguments: {e}")))?;

    let exec_started = Instant::now();

    let mut child = Command::new(exe)
        .arg("__harness_isolate_echo__")
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .kill_on_drop(true)
        .spawn()
        .map_err(|e| InvokeError::IsolationFailed(format!("spawn: {e}")))?;
    ISOLATE_COUNTERS.record_child_spawn_ok();

    if let Some(mut stdin) = child.stdin.take() {
        stdin
            .write_all(payload.as_bytes())
            .await
            .map_err(|e| InvokeError::IsolationFailed(format!("stdin: {e}")))?;
        stdin
            .shutdown()
            .await
            .map_err(|e| InvokeError::IsolationFailed(format!("stdin shutdown: {e}")))?;
    }

    let out = tokio::time::timeout(Duration::from_secs(10), child.wait_with_output())
        .await
        .map_err(|_| InvokeError::IsolationFailed("child timed out after 10s".into()))?
        .map_err(|e| InvokeError::IsolationFailed(format!("wait: {e}")))?;

    let child_execution_ms = exec_started.elapsed().as_millis() as u64;

    let result = if !out.status.success() {
        let stderr = String::from_utf8_lossy(&out.stderr);
        Err(InvokeError::IsolationFailed(format!(
            "child exit {:?}: {}",
            out.status.code(),
            stderr.trim()
        )))
    } else {
        let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
        serde_json::from_str(&stdout).map_err(|e| {
            InvokeError::IsolationFailed(format!("child stdout not json: {e}; raw={stdout:?}"))
        })
    };

    let available_snap = ISOLATE_SLOTS.available_permits();

    observe::harness_isolate_invoke_finished(
        queued_ahead,
        semaphore_wait_ms,
        child_execution_ms,
        available_snap,
        *ISOLATE_MAX_SLOTS,
        false,
        ISOLATE_COUNTERS
            .total_process_reuse_hits
            .load(Ordering::Relaxed),
    );

    result
}
