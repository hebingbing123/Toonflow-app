//! 进程隔离的 Harness 工具。
//!
//! 通过隐藏子命令启动相同二进制文件，使白名单工具逻辑在 API 进程外运行（地址空间边界），
//! 作为 vm2 风格的替代路径。
//! 并发数由 `HARNESS_ISOLATE_MAX_CONCURRENT` 限制（默认 4），防止并行 `isolated.echo` 调用耗尽进程/文件描述符。
//!
//! **可观测**：进入并发槽队列深度、Semaphore 等待时间、子进程执行耗时见 `observe::harness_isolate_invoke_finished`，
//! 聚合统计见 [`metrics_snapshot`]（WP‑D）；**[`GET /api/v1/ready`](crate::app::handlers::ready)** JSON 中带 **`harness_isolate`** 快照。
//!
//! **进程复用**：默认 **`HARNESS_ISOLATE_POOL` 启用**常驻子进程 `__harness_isolate_echo_pool__`（stdin 上以 `u32_be` 总长 + UTF‑8 JSON
//! 成帧，`len=0` 或 stdin 关闭则 worker 退出）。设 **`HARNESS_ISOLATE_POOL=0|false|no|off`** 退回「每条 invoke 单次 spawn」（旧行为）。
//!
//! 可选 **`HARNESS_ISOLATE_RUNNER_EXE`**：显式指定子进程二进制（默认为 [`std::env::current_exe`]）。集成测试常指向
//! **`CARGO_BIN_EXE_toonflow-server`**。

use std::io::{Read as _, Write as _};
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::LazyLock;
use std::time::{Duration, Instant};

use serde_json::Value;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::process::{Child, ChildStdin, ChildStdout, Command};
use tokio::sync::Mutex;
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

/// `HARNESS_ISOLATE_POOL=0|false|no|off` 关闭复用池；缺省或未识别值 **开启**。
#[inline]
fn parse_isolate_pool_enabled() -> bool {
    match std::env::var("HARNESS_ISOLATE_POOL") {
        Ok(s) => {
            let t = s.trim().to_ascii_lowercase();
            !(t.is_empty() || t == "0" || t == "false" || t == "no" || t == "off")
        }
        Err(_) => true,
    }
}

static ISOLATE_MAX_SLOTS: LazyLock<usize> = LazyLock::new(parse_isolate_max_slots);

static ISOLATE_POOL_ENABLED: LazyLock<bool> = LazyLock::new(parse_isolate_pool_enabled);

static ISOLATE_SLOTS: LazyLock<Semaphore> = LazyLock::new(|| Semaphore::new(*ISOLATE_MAX_SLOTS));

struct IsolateCounters {
    wait_queue_depth: AtomicUsize,
    total_invocations: AtomicU64,
    total_semaphore_wait_ms: AtomicU64,
    total_child_spawns: AtomicU64,
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

    #[inline]
    fn record_process_reuse_hit(&self) {
        self.total_process_reuse_hits
            .fetch_add(1, Ordering::Relaxed);
    }
}

static ISOLATE_COUNTERS: LazyLock<IsolateCounters> = LazyLock::new(IsolateCounters::new);

#[derive(Clone, Debug)]
pub struct IsolateMetricsSnapshot {
    pub max_slots: usize,
    pub queue_depth_waiting: usize,
    pub available_permits_snapshot: usize,
    pub total_invocations: u64,
    pub total_semaphore_wait_ms: u64,
    pub total_child_spawns: u64,
    pub total_process_reuse_hits: u64,
}

impl IsolateMetricsSnapshot {
    #[must_use]
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

/// Max UTF‑8 JSON body size (`u32_be` length prefix) per pooled **`isolated.echo`** round-trip.
pub const HARNESS_ISOLATE_POOL_MAX_PAYLOAD_BYTES: u32 = 4 * 1024 * 1024;

#[allow(dead_code)]
struct PooledEchoConn {
    /// Kept alive with piped stdin/stdout; drained on disconnect.
    child: Child,
    stdin: ChildStdin,
    stdout: ChildStdout,
}

enum PoolAcquireKind {
    PreferIdleElseSpawn,
    ForceSpawnOnly,
}

static POOL_IDLE: LazyLock<Mutex<Vec<PooledEchoConn>>> = LazyLock::new(|| Mutex::new(Vec::new()));

fn resolve_isolate_runner_exe() -> Result<PathBuf, InvokeError> {
    if let Ok(p) = std::env::var("HARNESS_ISOLATE_RUNNER_EXE") {
        let p = p.trim();
        if !p.is_empty() {
            return Ok(PathBuf::from(p));
        }
    }
    std::env::current_exe().map_err(|e| InvokeError::IsolationFailed(format!("current_exe: {e}")))
}

/// Child entry: read JSON from stdin, write same JSON to stdout (echo). Used by `isolated.echo` spawn-only path.
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

/// Framed pooled worker (`__harness_isolate_echo_pool__`): repeats `be32 len + JSON`, normalized echo back (`len = 0` or EOF ⇒ exit).
pub fn stdio_echo_pool_child() -> ! {
    let stdin = std::io::stdin();
    let stdout = std::io::stdout();
    let mut stdin_lock = stdin.lock();
    let mut stdout_lock = stdout.lock();
    let mut len_raw = [0u8; 4];

    loop {
        if stdin_lock.read_exact(&mut len_raw).is_err() {
            break;
        }
        let n = u32::from_be_bytes(len_raw);
        if n == 0 {
            break;
        }
        if n > HARNESS_ISOLATE_POOL_MAX_PAYLOAD_BYTES {
            eprintln!("harness isolate pool: payload {n} bytes exceeds max");
            std::process::exit(2);
        }
        let nu = n as usize;
        let mut body = vec![0u8; nu];
        if stdin_lock.read_exact(&mut body).is_err() {
            break;
        }
        let v: Value = match serde_json::from_slice(&body) {
            Ok(v) => v,
            Err(e) => {
                eprintln!("harness isolate pool: json: {e}");
                std::process::exit(3);
            }
        };
        let encoded = match serde_json::to_vec(&v) {
            Ok(b) => b,
            Err(e) => {
                eprintln!("harness isolate pool: serialize: {e}");
                std::process::exit(4);
            }
        };
        let out_len_u32 = match u32::try_from(encoded.len()) {
            Ok(u) => u,
            Err(_) => {
                eprintln!("harness isolate pool: response framing overflow");
                std::process::exit(5);
            }
        };
        if stdout_lock.write_all(&out_len_u32.to_be_bytes()).is_err() {
            break;
        }
        if stdout_lock.write_all(&encoded).is_err() || stdout_lock.flush().is_err() {
            break;
        }
    }
    std::process::exit(0);
}

async fn spawn_pooled_echo_worker(exe: &std::path::Path) -> Result<PooledEchoConn, InvokeError> {
    let mut child = Command::new(exe)
        .arg("__harness_isolate_echo_pool__")
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::null())
        .kill_on_drop(true)
        .spawn()
        .map_err(|e| InvokeError::IsolationFailed(format!("spawn pool worker: {e}")))?;

    ISOLATE_COUNTERS.record_child_spawn_ok();

    let stdin = child
        .stdin
        .take()
        .ok_or_else(|| InvokeError::IsolationFailed("pool stdin missing".into()))?;
    let stdout = child
        .stdout
        .take()
        .ok_or_else(|| InvokeError::IsolationFailed("pool stdout missing".into()))?;

    Ok(PooledEchoConn {
        child,
        stdin,
        stdout,
    })
}

async fn acquire_pooled_echo_conn(
    exe: &std::path::Path,
    kind: PoolAcquireKind,
) -> Result<(PooledEchoConn, bool), InvokeError> {
    match kind {
        PoolAcquireKind::ForceSpawnOnly => Ok((spawn_pooled_echo_worker(exe).await?, false)),
        PoolAcquireKind::PreferIdleElseSpawn => {
            let mut g = POOL_IDLE.lock().await;
            if let Some(c) = g.pop() {
                drop(g);
                Ok((c, true))
            } else {
                drop(g);
                Ok((spawn_pooled_echo_worker(exe).await?, false))
            }
        }
    }
}

async fn write_framed_payload(stdin: &mut ChildStdin, payload: &[u8]) -> Result<(), InvokeError> {
    let n = u32::try_from(payload.len()).map_err(|_| {
        InvokeError::IsolationFailed("isolated.echo payload exceeds u32 length".into())
    })?;
    stdin
        .write_all(&n.to_be_bytes())
        .await
        .map_err(|e| InvokeError::IsolationFailed(format!("isolate pool stdin hdr: {e}")))?;
    stdin
        .write_all(payload)
        .await
        .map_err(|e| InvokeError::IsolationFailed(format!("isolate pool stdin body: {e}")))?;
    stdin
        .flush()
        .await
        .map_err(|e| InvokeError::IsolationFailed(format!("isolate pool stdin flush: {e}")))?;
    Ok(())
}

async fn read_framed_payload(stdout: &mut ChildStdout) -> Result<Vec<u8>, InvokeError> {
    let mut hdr = [0u8; 4];
    stdout
        .read_exact(&mut hdr)
        .await
        .map_err(|e| InvokeError::IsolationFailed(format!("isolate pool stdout hdr: {e}")))?;
    let len = u32::from_be_bytes(hdr);
    if len == 0 {
        return Err(InvokeError::IsolationFailed(
            "isolate pool: empty stdout frame".into(),
        ));
    }
    if len > HARNESS_ISOLATE_POOL_MAX_PAYLOAD_BYTES {
        return Err(InvokeError::IsolationFailed(format!(
            "isolate pool: response {} bytes exceeds {}",
            len, HARNESS_ISOLATE_POOL_MAX_PAYLOAD_BYTES
        )));
    }
    let mut buf = vec![0u8; len as usize];
    stdout
        .read_exact(&mut buf)
        .await
        .map_err(|e| InvokeError::IsolationFailed(format!("isolate pool stdout body: {e}")))?;
    Ok(buf)
}

async fn pool_roundtrip_value(
    conn: &mut PooledEchoConn,
    payload: &[u8],
) -> Result<Value, InvokeError> {
    let fut = async {
        write_framed_payload(&mut conn.stdin, payload).await?;
        let out = read_framed_payload(&mut conn.stdout).await?;
        serde_json::from_slice(&out)
            .map_err(|e| InvokeError::IsolationFailed(format!("isolate pool stdout not json: {e}")))
    };
    tokio::time::timeout(Duration::from_secs(10), fut)
        .await
        .map_err(|_| InvokeError::IsolationFailed("child timed out after 10s".into()))?
}

async fn return_idle_maybe(conn: PooledEchoConn) {
    let mut g = POOL_IDLE.lock().await;
    if g.len() < *ISOLATE_MAX_SLOTS {
        g.push(conn);
    }
}

/// Two attempts: reused idle worker if any else spawn; second pass always freshly spawned worker.
async fn pooled_isolated_echo(
    exe: &std::path::Path,
    payload: &[u8],
) -> Result<(Value, bool), InvokeError> {
    let mut last_err: Option<InvokeError> = None;

    for kind in [
        PoolAcquireKind::PreferIdleElseSpawn,
        PoolAcquireKind::ForceSpawnOnly,
    ] {
        let (mut conn, pooled_from_idle) = acquire_pooled_echo_conn(exe, kind).await?;

        match pool_roundtrip_value(&mut conn, payload).await {
            Ok(v) => {
                let reuse_observed = pooled_from_idle;
                if reuse_observed {
                    ISOLATE_COUNTERS.record_process_reuse_hit();
                }
                return_idle_maybe(conn).await;
                return Ok((v, reuse_observed));
            }
            Err(err) => {
                last_err = Some(err);
                drop(conn);
            }
        }
    }

    Err(last_err.unwrap_or_else(|| InvokeError::IsolationFailed("isolate pool gave up".into())))
}

async fn isolated_echo_spawn_once_inner(
    exe: &std::path::Path,
    payload: &[u8],
) -> Result<Value, InvokeError> {
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
            .write_all(payload)
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

    if !out.status.success() {
        let stderr = String::from_utf8_lossy(&out.stderr);
        return Err(InvokeError::IsolationFailed(format!(
            "child exit {:?}: {}",
            out.status.code(),
            stderr.trim()
        )));
    }
    let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
    serde_json::from_str(&stdout).map_err(|e| {
        InvokeError::IsolationFailed(format!("child stdout not json: {e}; raw={stdout:?}"))
    })
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

    let payload = serde_json::to_vec(arguments)
        .map_err(|e| InvokeError::IsolationFailed(format!("serialize arguments: {e}")))?;

    let exec_started = Instant::now();

    let (result, reuse_hit) = if *ISOLATE_POOL_ENABLED {
        pooled_isolated_echo(exe.as_path(), &payload).await?
    } else {
        (
            isolated_echo_spawn_once_inner(exe.as_path(), &payload).await?,
            false,
        )
    };

    let child_execution_ms = exec_started.elapsed().as_millis() as u64;

    let available_snap = ISOLATE_SLOTS.available_permits();

    observe::harness_isolate_invoke_finished(
        queued_ahead,
        semaphore_wait_ms,
        child_execution_ms,
        available_snap,
        *ISOLATE_MAX_SLOTS,
        reuse_hit,
        ISOLATE_COUNTERS
            .total_process_reuse_hits
            .load(Ordering::Relaxed),
    );

    Ok(result)
}
