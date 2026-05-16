//! Export_Tool：将指定 quality_review_id 集合导出为 Bad_Case_Fixture JSON 文件。
//!
//! 用法：
//! ```
//! cargo run --bin quality-export -- --ids <id1,id2,...> --output <path>
//! cargo run --bin quality-export -- --ids-file <path> --output <path>
//! cargo run --bin quality-export -- --ids <id1,...> --stage storyboard_panel --output <path>
//! ```
//!
//! 只读操作，不修改任何数据库记录。
//! Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 5.5

use std::path::PathBuf;

use chrono::Utc;
use clap::Parser;
use sqlx::postgres::PgPoolOptions;
use uuid::Uuid;

use toonflow_server::prompting::quality::dimension::{BadCaseFixture, FixtureReview};

/// 合法的生成阶段值（与 validate.rs 中的 VALID_STAGES 保持一致）
const VALID_STAGES: &[&str] = &[
    "story_skeleton",
    "adaptation_strategy",
    "director_planning",
    "storyboard_table",
    "storyboard_panel",
    "video_prompt",
];

/// Export_Tool CLI 参数定义
#[derive(Parser, Debug)]
#[command(
    name = "quality-export",
    about = "将指定 quality_review_id 集合导出为 Bad_Case_Fixture JSON 文件（只读）",
    long_about = None
)]
struct Args {
    /// 逗号分隔的 UUID 列表（与 --ids-file 互斥）
    #[arg(long, value_delimiter = ',', conflicts_with = "ids_file")]
    ids: Vec<Uuid>,

    /// 换行分隔的 UUID 文件路径（与 --ids 互斥）
    #[arg(long, conflicts_with = "ids")]
    ids_file: Option<PathBuf>,

    /// 可选：仅导出指定 Stage 的评审记录
    #[arg(long)]
    stage: Option<String>,

    /// 输出 JSON 文件路径
    #[arg(long)]
    output: PathBuf,
}

/// 数据库查询结果行（对应 app_quality_review 表字段）
#[derive(sqlx::FromRow)]
struct ReviewRow {
    id: Uuid,
    stage: Option<String>,
    grade: Option<String>,
    passed: Option<bool>,
    overall_score: Option<i16>,
    dimension_scores: Option<serde_json::Value>,
    is_bad_case: bool,
    bad_case_category: Option<String>,
    skill_version_hash: Option<String>,
    created_at: chrono::DateTime<Utc>,
}

#[tokio::main]
async fn main() {
    let args = Args::parse();

    // 1. 校验 --stage 合法性（需求 4.7）
    if let Some(ref stage) = args.stage {
        if !VALID_STAGES.contains(&stage.as_str()) {
            eprintln!(
                "ERROR: invalid stage: {}, valid values: {:?}",
                stage, VALID_STAGES
            );
            std::process::exit(1);
        }
    }

    // 2. 收集 ID 列表（需求 4.2, 4.6）
    let ids = collect_ids(&args);

    if ids.is_empty() {
        eprintln!("ERROR: no IDs provided. Use --ids or --ids-file.");
        std::process::exit(1);
    }

    // 3. 建立数据库连接（需求 4.5）
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

    // 4. 批量查询（需求 4.2, 4.3）
    let rows = match fetch_reviews(&pool, &ids).await {
        Ok(r) => r,
        Err(e) => {
            eprintln!("ERROR: database query failed: {}", e);
            std::process::exit(1);
        }
    };

    // 5. 处理不存在的 ID（需求 4.4）
    let fetched_ids: std::collections::HashSet<Uuid> = rows.iter().map(|r| r.id).collect();
    for id in &ids {
        if !fetched_ids.contains(id) {
            eprintln!("WARN: review {} not found, skipped", id);
        }
    }

    // 6. 可选 stage 过滤（需求 4.7）
    let filtered_rows: Vec<ReviewRow> = if let Some(ref stage_filter) = args.stage {
        rows.into_iter()
            .filter(|r| r.stage.as_deref() == Some(stage_filter.as_str()))
            .collect()
    } else {
        rows
    };

    // 7. 组装 BadCaseFixture（需求 4.3, 5.5）
    let reviews: Vec<FixtureReview> = filtered_rows
        .into_iter()
        .map(|row| FixtureReview {
            id: row.id,
            stage: row.stage,
            grade: row.grade,
            passed: row.passed,
            overall_score: row.overall_score,
            dimension_scores: row.dimension_scores,
            is_bad_case: row.is_bad_case,
            bad_case_category: row.bad_case_category,
            skill_version_hash: row.skill_version_hash,
            created_at: row.created_at,
        })
        .collect();

    let fixture = BadCaseFixture {
        exported_at: Utc::now(),
        review_count: reviews.len(),
        schema_version: "1".to_string(),
        reviews,
    };

    // 8. 序列化并写入输出文件（需求 4.2）
    let json = match serde_json::to_string_pretty(&fixture) {
        Ok(j) => j,
        Err(e) => {
            eprintln!("ERROR: serialization failed: {}", e);
            std::process::exit(1);
        }
    };

    if let Some(parent) = args.output.parent() {
        if !parent.as_os_str().is_empty() {
            if let Err(e) = std::fs::create_dir_all(parent) {
                eprintln!(
                    "ERROR: cannot create output directory {}: {}",
                    parent.display(),
                    e
                );
                std::process::exit(1);
            }
        }
    }

    if let Err(e) = std::fs::write(&args.output, &json) {
        eprintln!("ERROR: cannot write to {}: {}", args.output.display(), e);
        std::process::exit(1);
    }

    println!(
        "Exported {} reviews to {}",
        fixture.review_count,
        args.output.display()
    );
}

/// 从 CLI 参数收集 UUID 列表。
///
/// - `--ids` 直接使用 clap 解析的 Vec<Uuid>
/// - `--ids-file` 读取文件，每行一个 UUID，忽略空行与注释行（`#` 开头）
fn collect_ids(args: &Args) -> Vec<Uuid> {
    if !args.ids.is_empty() {
        return args.ids.clone();
    }

    if let Some(ref path) = args.ids_file {
        let content = match std::fs::read_to_string(path) {
            Ok(c) => c,
            Err(e) => {
                eprintln!("ERROR: cannot read ids-file {}: {}", path.display(), e);
                std::process::exit(1);
            }
        };

        let mut ids = Vec::new();
        for (line_no, line) in content.lines().enumerate() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }
            match trimmed.parse::<Uuid>() {
                Ok(id) => ids.push(id),
                Err(_) => {
                    eprintln!(
                        "ERROR: invalid UUID on line {} of {}: {:?}",
                        line_no + 1,
                        path.display(),
                        trimmed
                    );
                    std::process::exit(1);
                }
            }
        }
        return ids;
    }

    Vec::new()
}

/// 批量查询数据库，返回匹配 ID 的评审记录。
async fn fetch_reviews(pool: &sqlx::PgPool, ids: &[Uuid]) -> Result<Vec<ReviewRow>, sqlx::Error> {
    // 使用非宏版本 query_as 避免编译时数据库检查（dimension_scores 列由 migration 添加）
    let rows = sqlx::query_as::<_, ReviewRow>(
        r#"
        SELECT
            id,
            stage,
            grade,
            passed,
            overall_score,
            dimension_scores,
            is_bad_case,
            bad_case_category,
            skill_version_hash,
            created_at
        FROM app_quality_review
        WHERE id = ANY($1)
        "#,
    )
    .bind(ids)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}
