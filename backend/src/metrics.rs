//! 性能指标收集模块
//!
//! 提供关键业务指标的记录功能，包括：
//! - API 请求延迟和成功率
//! - TTS 生成成功率和耗时
//! - 导出任务耗时和成功率
//! - 批量操作统计

use std::time::Duration;
use tracing::{info, warn};

/// 记录 API 请求指标
pub fn record_api_request(endpoint: &str, method: &str, status_code: u16, duration: Duration) {
    info!(
        target: "openflow.metrics.api",
        endpoint = %endpoint,
        method = %method,
        status_code = %status_code,
        duration_ms = %duration.as_millis(),
        "API request completed"
    );
}

/// 记录 TTS 生成指标
pub fn record_tts_generation(
    provider: &str,
    voice_id: &str,
    success: bool,
    duration: Duration,
    error: Option<&str>,
) {
    if success {
        info!(
            target: "openflow.metrics.tts",
            provider = %provider,
            voice_id = %voice_id,
            duration_ms = %duration.as_millis(),
            success = true,
            "TTS generation completed successfully"
        );
    } else {
        warn!(
            target: "openflow.metrics.tts",
            provider = %provider,
            voice_id = %voice_id,
            duration_ms = %duration.as_millis(),
            success = false,
            error = %error.unwrap_or("unknown"),
            "TTS generation failed"
        );
    }
}

/// 记录导出任务指标
pub fn record_export_task(
    format: &str,
    quality: &str,
    success: bool,
    duration: Duration,
    file_size_bytes: Option<u64>,
    error: Option<&str>,
) {
    if success {
        info!(
            target: "openflow.metrics.export",
            format = %format,
            quality = %quality,
            duration_ms = %duration.as_millis(),
            file_size_bytes = ?file_size_bytes,
            success = true,
            "Export task completed successfully"
        );
    } else {
        warn!(
            target: "openflow.metrics.export",
            format = %format,
            quality = %quality,
            duration_ms = %duration.as_millis(),
            success = false,
            error = %error.unwrap_or("unknown"),
            "Export task failed"
        );
    }
}

/// 记录批量操作指标
pub fn record_batch_operation(
    operation: &str,
    total_count: usize,
    success_count: usize,
    failed_count: usize,
    duration: Duration,
) {
    let success_rate = if total_count > 0 {
        (success_count as f64 / total_count as f64) * 100.0
    } else {
        0.0
    };

    info!(
        target: "openflow.metrics.batch",
        operation = %operation,
        total_count = %total_count,
        success_count = %success_count,
        failed_count = %failed_count,
        success_rate = %format!("{:.2}%", success_rate),
        duration_ms = %duration.as_millis(),
        "Batch operation completed"
    );
}

/// 记录数据库查询指标
pub fn record_db_query(query_name: &str, duration: Duration, rows_affected: Option<u64>) {
    info!(
        target: "openflow.metrics.db",
        query_name = %query_name,
        duration_ms = %duration.as_millis(),
        rows_affected = ?rows_affected,
        "Database query completed"
    );
}

/// 记录缓存操作指标
pub fn record_cache_operation(operation: &str, cache_key: &str, hit: bool, duration: Duration) {
    info!(
        target: "openflow.metrics.cache",
        operation = %operation,
        cache_key = %cache_key,
        hit = %hit,
        duration_ms = %duration.as_millis(),
        "Cache operation completed"
    );
}

/// 记录计费对账不匹配指标
///
/// Task 4.3: Reconciliation metrics for shadow period monitoring.
pub fn record_billing_reconciliation_mismatch(field: &str) {
    warn!(
        target: "openflow.metrics.billing_reconciliation",
        field = %field,
        "Billing reconciliation mismatch detected"
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_record_api_request() {
        record_api_request("/api/v1/test", "GET", 200, Duration::from_millis(150));
    }

    #[test]
    fn test_record_tts_generation_success() {
        record_tts_generation("openai", "alloy", true, Duration::from_secs(2), None);
    }

    #[test]
    fn test_record_tts_generation_failure() {
        record_tts_generation(
            "openai",
            "alloy",
            false,
            Duration::from_secs(1),
            Some("API rate limit exceeded"),
        );
    }

    #[test]
    fn test_record_export_task_success() {
        record_export_task(
            "mp4",
            "1080p",
            true,
            Duration::from_secs(30),
            Some(10_485_760),
            None,
        );
    }

    #[test]
    fn test_record_export_task_failure() {
        record_export_task(
            "mp4",
            "1080p",
            false,
            Duration::from_secs(5),
            None,
            Some("Encoding failed"),
        );
    }

    #[test]
    fn test_record_batch_operation() {
        record_batch_operation("batch_select", 100, 95, 5, Duration::from_secs(3));
    }

    #[test]
    fn test_record_db_query() {
        record_db_query("select_shots", Duration::from_millis(50), Some(100));
    }

    #[test]
    fn test_record_cache_operation() {
        record_cache_operation("get", "user:123:profile", true, Duration::from_micros(500));
    }

    #[test]
    fn test_record_billing_reconciliation_mismatch() {
        record_billing_reconciliation_mismatch("plan_tier");
    }
}
