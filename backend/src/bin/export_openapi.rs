//! Emit the merged OpenAPI document (Rust shell + embedded legacy schemas + path index + utoipa) to stdout.
//!
//! ```text
//! cargo run --bin export-openapi --manifest-path backend/Cargo.toml > openapi.export.yaml
//! ```

fn main() -> anyhow::Result<()> {
    let yaml = toonflow_server::openapi_spec::merged_openapi_yaml_string()?;
    print!("{yaml}");
    Ok(())
}
