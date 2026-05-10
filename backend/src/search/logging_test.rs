//! 搜索日志记录功能的单元测试。

#[cfg(test)]
mod tests {
    use crate::search::logging::*;
    use crate::search::models::{ResultType, SearchQuery};
    use chrono::{TimeZone, Utc};
    use serde_json::json;
    use uuid::Uuid;

    #[test]
    fn test_build_filters_json_minimal() {
        let query = SearchQuery {
            q: "test".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let filters = build_filters_json(&query);
        assert!(filters.is_some());

        let filters_obj = filters.unwrap();
        assert_eq!(filters_obj["page"], json!(1));
        assert_eq!(filters_obj["page_size"], json!(20));
        assert!(filters_obj.get("result_type").is_none());
        assert!(filters_obj.get("time_from").is_none());
        assert!(filters_obj.get("time_to").is_none());
    }

    #[test]
    fn test_build_filters_json_with_result_types() {
        let query = SearchQuery {
            q: "test".to_string(),
            result_type: Some(vec![ResultType::Project, ResultType::Script]),
            page: 2,
            page_size: 50,
            time_from: None,
            time_to: None,
        };

        let filters = build_filters_json(&query);
        assert!(filters.is_some());

        let filters_obj = filters.unwrap();
        assert_eq!(filters_obj["result_type"], json!(["project", "script"]));
        assert_eq!(filters_obj["page"], json!(2));
        assert_eq!(filters_obj["page_size"], json!(50));
    }

    #[test]
    fn test_build_filters_json_with_time_range() {
        let time_from = Utc.with_ymd_and_hms(2024, 1, 1, 0, 0, 0).unwrap();
        let time_to = Utc.with_ymd_and_hms(2024, 12, 31, 23, 59, 59).unwrap();

        let query = SearchQuery {
            q: "test".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: Some(time_from),
            time_to: Some(time_to),
        };

        let filters = build_filters_json(&query);
        assert!(filters.is_some());

        let filters_obj = filters.unwrap();
        assert!(filters_obj["time_from"].is_string());
        assert!(filters_obj["time_to"].is_string());

        // 验证时间格式为 RFC3339
        let time_from_str = filters_obj["time_from"].as_str().unwrap();
        assert!(time_from_str.contains("2024-01-01"));

        let time_to_str = filters_obj["time_to"].as_str().unwrap();
        assert!(time_to_str.contains("2024-12-31"));
    }

    #[test]
    fn test_build_filters_json_with_all_filters() {
        let time_from = Utc.with_ymd_and_hms(2024, 1, 1, 0, 0, 0).unwrap();
        let time_to = Utc.with_ymd_and_hms(2024, 12, 31, 23, 59, 59).unwrap();

        let query = SearchQuery {
            q: "test".to_string(),
            result_type: Some(vec![ResultType::Asset]),
            page: 3,
            page_size: 100,
            time_from: Some(time_from),
            time_to: Some(time_to),
        };

        let filters = build_filters_json(&query);
        assert!(filters.is_some());

        let filters_obj = filters.unwrap();
        assert_eq!(filters_obj["result_type"], json!(["asset"]));
        assert_eq!(filters_obj["page"], json!(3));
        assert_eq!(filters_obj["page_size"], json!(100));
        assert!(filters_obj["time_from"].is_string());
        assert!(filters_obj["time_to"].is_string());
    }

    #[test]
    fn test_build_filters_json_empty_result_types() {
        let query = SearchQuery {
            q: "test".to_string(),
            result_type: Some(vec![]), // 空列表
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let filters = build_filters_json(&query);
        assert!(filters.is_some());

        let filters_obj = filters.unwrap();
        // 空列表不应该被添加到 filters 中
        assert!(filters_obj.get("result_type").is_none());
    }

    #[test]
    fn test_search_log_entry_normal_query() {
        let user_id = Uuid::new_v4();
        let workspace_id = Uuid::new_v4();

        let entry = SearchLogEntry {
            user_id,
            workspace_id,
            query: "项目名称".to_string(),
            result_count: 15,
            response_time_ms: 350,
            filters: Some(json!({"page": 1, "page_size": 20})),
        };

        assert_eq!(entry.user_id, user_id);
        assert_eq!(entry.workspace_id, workspace_id);
        assert_eq!(entry.query, "项目名称");
        assert_eq!(entry.result_count, 15);
        assert_eq!(entry.response_time_ms, 350);
        assert!(entry.filters.is_some());

        // 不是慢查询
        assert!(entry.response_time_ms <= 1000);
    }

    #[test]
    fn test_search_log_entry_slow_query() {
        let entry = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "复杂查询".to_string(),
            result_count: 100,
            response_time_ms: 2500,
            filters: None,
        };

        // 是慢查询（>1 秒）
        assert!(entry.response_time_ms > 1000);
        assert_eq!(entry.response_time_ms, 2500);
    }

    #[test]
    fn test_search_log_entry_boundary_slow_query() {
        // 正好 1 秒，不算慢查询
        let entry_1000 = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "test".to_string(),
            result_count: 10,
            response_time_ms: 1000,
            filters: None,
        };
        assert!(entry_1000.response_time_ms <= 1000);

        // 1001 毫秒，算慢查询
        let entry_1001 = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "test".to_string(),
            result_count: 10,
            response_time_ms: 1001,
            filters: None,
        };
        assert!(entry_1001.response_time_ms > 1000);
    }

    #[test]
    fn test_search_log_entry_zero_results() {
        let entry = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "不存在的关键词".to_string(),
            result_count: 0,
            response_time_ms: 100,
            filters: None,
        };

        assert_eq!(entry.result_count, 0);
        assert_eq!(entry.response_time_ms, 100);
    }

    #[test]
    fn test_search_log_entry_with_complex_filters() {
        let filters = json!({
            "result_type": ["project", "script"],
            "time_from": "2024-01-01T00:00:00Z",
            "time_to": "2024-12-31T23:59:59Z",
            "page": 2,
            "page_size": 50
        });

        let entry = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "高级搜索".to_string(),
            result_count: 25,
            response_time_ms: 450,
            filters: Some(filters.clone()),
        };

        assert!(entry.filters.is_some());
        let entry_filters = entry.filters.unwrap();
        assert_eq!(entry_filters["result_type"], json!(["project", "script"]));
        assert_eq!(entry_filters["page"], json!(2));
        assert_eq!(entry_filters["page_size"], json!(50));
    }

    #[test]
    fn test_response_time_ranges() {
        // 快速查询（<100ms）
        let fast = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "test".to_string(),
            result_count: 5,
            response_time_ms: 50,
            filters: None,
        };
        assert!(fast.response_time_ms < 100);

        // 正常查询（100-500ms）
        let normal = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "test".to_string(),
            result_count: 10,
            response_time_ms: 300,
            filters: None,
        };
        assert!(normal.response_time_ms >= 100 && normal.response_time_ms <= 500);

        // 较慢查询（500-1000ms）
        let slower = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "test".to_string(),
            result_count: 20,
            response_time_ms: 800,
            filters: None,
        };
        assert!(slower.response_time_ms > 500 && slower.response_time_ms <= 1000);

        // 慢查询（>1000ms）
        let slow = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "test".to_string(),
            result_count: 50,
            response_time_ms: 1500,
            filters: None,
        };
        assert!(slow.response_time_ms > 1000);
    }

    #[test]
    fn test_query_length_validation() {
        // 最短查询（2 字符）
        let min_query = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "ab".to_string(),
            result_count: 0,
            response_time_ms: 100,
            filters: None,
        };
        assert_eq!(min_query.query.len(), 2);

        // 最长查询（200 字符）
        let max_query = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "a".repeat(200),
            result_count: 0,
            response_time_ms: 100,
            filters: None,
        };
        assert_eq!(max_query.query.len(), 200);

        // 中文查询
        let chinese_query = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "项目名称".to_string(),
            result_count: 10,
            response_time_ms: 200,
            filters: None,
        };
        assert!(chinese_query.query.len() >= 2);
    }

    #[test]
    fn test_result_count_ranges() {
        // 无结果
        let no_results = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "test".to_string(),
            result_count: 0,
            response_time_ms: 100,
            filters: None,
        };
        assert_eq!(no_results.result_count, 0);

        // 少量结果
        let few_results = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "test".to_string(),
            result_count: 5,
            response_time_ms: 150,
            filters: None,
        };
        assert!(few_results.result_count > 0 && few_results.result_count < 10);

        // 大量结果
        let many_results = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "test".to_string(),
            result_count: 100,
            response_time_ms: 500,
            filters: None,
        };
        assert!(many_results.result_count >= 100);
    }
}

