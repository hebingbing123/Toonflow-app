//! Regression_Check_Tool：读取 Bad_Case_Fixture 并与数据库当前状态对比，输出退化报告。
//!
//! 用法：
//! ```
//! cargo run --bin quality-regression-check -- --fixture <path>
//! ```
//!
//! 只读操作，不修改任何数据库记录。
//! 退出码：
//!   0 — regression_rate <= 0.1
//!   1 — regression_rate > 0.1
//!   2 — fixture 文件解析失败或缺少必要字段
//!
//! Requirements: 7.1, 7.2, 7.3, 7.4, 7.5

use std::collections::HashMap;
use std::path::PathBuf;

use clap::Parser;
use sqlx::postgres::PgPoolOptions;
use uuid::Uuid;

use toonflow_server::prompting::quality::dimension::{
    BadCaseFixture, RegressionItem, RegressionReport,
};

/// Regression_Check_Tool CLI 参数定义
#[derive(Parser, Debug)]
#[command(
    name = "quality-regression-check",
    about = "读取 Bad_Case_Fixture 并与数据库当前状态对比，输出结构化退化报告（只读）",
    long_about = None
)]
struct Args {
    /// Fixture JSON 文件路径
    #[arg(long)]
    fixture: PathBuf,
}

/// 数据库查询结果行（仅需 id 与 passed 字段）
#[derive(sqlx::FromRow)]
struct PassedRow {
    id: Uuid,
    passed: Option<bool>,
}

#[tokio::main]
async fn main() {
    let args = Args::parse();

    // 1. 读取 fixture 文件（需求 7.5）
    let content = match std::fs::read_to_string(&args.fixture) {
        Ok(c) => c,
        Err(e) => {
            eprintln!(
                "ERROR: cannot read fixture file {}: {}",
                args.fixture.display(),
                e
            );
            std::process::exit(2);
        }
    };

    // 2. 解析 fixture JSON（需求 7.5）
    // 先解析为 serde_json::Value 以便校验必要字段存在
    let raw: serde_json::Value = match serde_json::from_str(&content) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("ERROR: invalid fixture: JSON parse error: {}", e);
            std::process::exit(2);
        }
    };

    // 校验 schemaVersion 字段存在（需求 7.5）
    if raw.get("schemaVersion").is_none() {
        eprintln!("ERROR: missing required field: schemaVersion");
        std::process::exit(2);
    }

    // 校验 reviews 字段存在（需求 7.5）
    if raw.get("reviews").is_none() {
        eprintln!("ERROR: missing required field: reviews");
        std::process::exit(2);
    }

    // 反序列化为强类型结构
    let fixture: BadCaseFixture = match serde_json::from_value(raw) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("ERROR: invalid fixture: {}", e);
            std::process::exit(2);
        }
    };

    // 3. 建立数据库连接（需求 7.1）
    let database_url = match std::env::var("DATABASE_URL") {
        Ok(url) => url,
        Err(_) => {
            eprintln!("ERROR: DATABASE_URL environment variable is not set");
            std::process::exit(1);
        }
    };

    let pool = match PgPoolOptions::new()
        .max_connections(2)
        .connect(&database_url)
        .await
    {
        Ok(p) => p,
        Err(e) => {
            eprintln!("ERROR: database connection failed: {}", e);
            std::process::exit(1);
        }
    };

    // 4. 收集 fixture 中所有 ID（需求 7.2）
    let fixture_ids: Vec<Uuid> = fixture.reviews.iter().map(|r| r.id).collect();

    if fixture_ids.is_empty() {
        // 空 fixture：无退化，直接输出报告
        let report = RegressionReport {
            fixture_file: args.fixture.display().to_string(),
            total_checked: 0,
            regression_count: 0,
            regression_rate: 0.0,
            regressions: vec![],
        };
        println!("{}", serde_json::to_string_pretty(&report).unwrap());
        std::process::exit(0);
    }

    // 5. 批量查询数据库（需求 7.2）
    let db_rows = match fetch_passed_status(&pool, &fixture_ids).await {
        Ok(rows) => rows,
        Err(e) => {
            eprintln!("ERROR: database query failed: {}", e);
            std::process::exit(1);
        }
    };

    // 构建 id → passed 映射
    let db_map: HashMap<Uuid, Option<bool>> =
        db_rows.into_iter().map(|r| (r.id, r.passed)).collect();

    // 6. 对比每条记录（需求 7.2, 7.4）
    let mut total_checked: usize = 0;
    let mut regressions: Vec<RegressionItem> = Vec::new();

    for review in &fixture.reviews {
        match db_map.get(&review.id) {
            None => {
                // ID 不存在于数据库，跳过，不计入分母（需求 7.4）
                eprintln!("WARN: review {} not found in DB, skipped", review.id);
            }
            Some(db_passed) => {
                total_checked += 1;
                // 对比 fixture.passed 与 db.passed（需求 7.2）
                if review.passed != *db_passed {
                    regressions.push(RegressionItem {
                        id: review.id,
                        fixture_passed: review.passed,
                        current_passed: *db_passed,
                    });
                }
            }
        }
    }

    // 7. 计算退化率（需求 7.7）
    let regression_count = regressions.len();
    let regression_rate = if total_checked == 0 {
        0.0
    } else {
        regression_count as f64 / total_checked as f64
    };

    // 8. 构建并输出 RegressionReport JSON 到 stdout（需求 7.3）
    let report = RegressionReport {
        fixture_file: args.fixture.display().to_string(),
        total_checked,
        regression_count,
        regression_rate,
        regressions,
    };

    println!("{}", serde_json::to_string_pretty(&report).unwrap());

    // 9. 退出码（需求 7.4）
    if regression_rate > 0.1 {
        std::process::exit(1);
    } else {
        std::process::exit(0);
    }
}

/// 批量查询数据库，返回匹配 ID 的 (id, passed) 记录。
async fn fetch_passed_status(
    pool: &sqlx::PgPool,
    ids: &[Uuid],
) -> Result<Vec<PassedRow>, sqlx::Error> {
    let rows = sqlx::query_as::<_, PassedRow>(
        r#"
        SELECT id, passed
        FROM app_quality_review
        WHERE id = ANY($1)
        "#,
    )
    .bind(ids)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}
