use chrono::{DateTime, Utc};
use sqlx::QueryBuilder;

#[derive(Debug, Clone)]
pub(super) struct EventFilters {
    pub informational_event: Option<bool>,
    pub provider: Option<String>,
    pub raw_event_id: Option<String>,
    pub raw_event_id_prefix: Option<String>,
    pub event_type: Option<String>,
    pub provider_event_id: Option<String>,
    pub provider_event_id_prefix: Option<String>,
    pub event_created_from: Option<DateTime<Utc>>,
    pub event_created_to: Option<DateTime<Utc>>,
    pub created_from: Option<DateTime<Utc>>,
    pub created_to: Option<DateTime<Utc>>,
    pub id_min: Option<i64>,
    pub id_max: Option<i64>,
}

macro_rules! push_filter {
    ($qb:expr, $has_where:expr, $col:literal, $op:literal, $val:expr) => {{
        $qb.push(if $has_where { " AND " } else { " WHERE " });
        $qb.push(concat!($col, " ", $op, " "));
        $qb.push_bind($val);
        $has_where = true;
    }};
}

pub(super) fn build_count_query(filters: &EventFilters) -> QueryBuilder<'static, sqlx::Postgres> {
    let mut qb = QueryBuilder::new("SELECT COUNT(*)::bigint FROM app_billing_webhook_event");
    let mut has_where = false;
    apply_filters(&mut qb, &mut has_where, filters);
    qb
}

pub(super) fn build_items_query(
    filters: &EventFilters,
    sort: &'static str,
    limit: i64,
    offset: i64,
) -> QueryBuilder<'static, sqlx::Postgres> {
    let mut qb = QueryBuilder::new(
        r#"SELECT id, provider_event_id, provider, raw_event_id, event_type,
                  event_created_at, is_informational_event, created_at
           FROM app_billing_webhook_event"#,
    );
    let mut has_where = false;
    apply_filters(&mut qb, &mut has_where, filters);

    qb.push(" ORDER BY ");
    qb.push(sort);
    qb.push(" LIMIT ");
    qb.push_bind(limit);
    qb.push(" OFFSET ");
    qb.push_bind(offset);
    qb
}

fn apply_filters(
    qb: &mut QueryBuilder<'_, sqlx::Postgres>,
    has_where: &mut bool,
    filters: &EventFilters,
) {
    if let Some(v) = filters.informational_event {
        push_filter!(qb, *has_where, "is_informational_event", "=", v);
    }
    if let Some(v) = filters.provider.clone() {
        push_filter!(qb, *has_where, "provider", "=", v);
    }
    if let Some(v) = filters.raw_event_id.clone() {
        push_filter!(qb, *has_where, "raw_event_id", "=", v);
    }
    if let Some(prefix) = filters.raw_event_id_prefix.clone() {
        push_filter!(qb, *has_where, "raw_event_id", "LIKE", format!("{prefix}%"));
    }
    if let Some(v) = filters.event_type.clone() {
        push_filter!(qb, *has_where, "event_type", "=", v);
    }
    if let Some(v) = filters.provider_event_id.clone() {
        push_filter!(qb, *has_where, "provider_event_id", "=", v);
    }
    if let Some(prefix) = filters.provider_event_id_prefix.clone() {
        push_filter!(
            qb,
            *has_where,
            "provider_event_id",
            "LIKE",
            format!("{prefix}%")
        );
    }
    if let Some(v) = filters.event_created_from {
        push_filter!(qb, *has_where, "event_created_at", ">=", v);
    }
    if let Some(v) = filters.event_created_to {
        push_filter!(qb, *has_where, "event_created_at", "<=", v);
    }
    if let Some(v) = filters.created_from {
        push_filter!(qb, *has_where, "created_at", ">=", v);
    }
    if let Some(v) = filters.created_to {
        push_filter!(qb, *has_where, "created_at", "<=", v);
    }
    if let Some(v) = filters.id_min {
        push_filter!(qb, *has_where, "id", ">=", v);
    }
    if let Some(v) = filters.id_max {
        push_filter!(qb, *has_where, "id", "<=", v);
    }
}

#[cfg(test)]
mod tests {
    use chrono::{TimeZone, Utc};
    use sqlx::Execute;

    use super::{build_count_query, build_items_query, EventFilters};

    fn sample_filters() -> EventFilters {
        EventFilters {
            informational_event: Some(true),
            provider: Some("stripe".into()),
            raw_event_id: None,
            raw_event_id_prefix: Some("evt_".into()),
            event_type: Some("invoice.paid".into()),
            provider_event_id: None,
            provider_event_id_prefix: Some("stripe:".into()),
            event_created_from: Some(Utc.with_ymd_and_hms(2026, 4, 17, 10, 0, 0).unwrap()),
            event_created_to: None,
            created_from: None,
            created_to: Some(Utc.with_ymd_and_hms(2026, 4, 17, 12, 0, 0).unwrap()),
            id_min: Some(10),
            id_max: Some(20),
        }
    }

    #[test]
    fn build_count_query_applies_requested_filters() {
        let sql = build_count_query(&sample_filters())
            .build()
            .sql()
            .to_string();
        assert!(sql.contains("SELECT COUNT(*)::bigint FROM app_billing_webhook_event"));
        assert!(sql.contains("is_informational_event ="));
        assert!(sql.contains("provider ="));
        assert!(sql.contains("raw_event_id LIKE"));
        assert!(sql.contains("event_type ="));
        assert!(sql.contains("provider_event_id LIKE"));
        assert!(sql.contains("event_created_at >="));
        assert!(sql.contains("created_at <="));
        assert!(sql.contains("id >="));
        assert!(sql.contains("id <="));
    }

    #[test]
    fn build_items_query_appends_sort_limit_and_offset() {
        let sql = build_items_query(&sample_filters(), "id ASC", 25, 50)
            .build()
            .sql()
            .to_string();
        assert!(sql.contains("FROM app_billing_webhook_event"));
        assert!(sql.contains("ORDER BY id ASC"));
        assert!(sql.contains("LIMIT"));
        assert!(sql.contains("OFFSET"));
    }
}
