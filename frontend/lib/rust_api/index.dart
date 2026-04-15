export 'core.dart';
export 'agents/index.dart';
export 'assets/index.dart';
export 'catalog/index.dart';
export 'harness/index.dart';
export 'jobs/index.dart';
export 'novels/index.dart';
export 'production.dart';
export 'project/index.dart';
export 'quality/index.dart';
export 'settings/index.dart';
export 'shared_kernel/index.dart';
export 'skills/index.dart';
export 'scripts/index.dart';
export 'system/index.dart';

/// `POST /api/v1/production/get-production-data` — OpenAPI `postProductionGetProductionDataV1` (implemented in Rust; returns **200** or **503** without DB).

// --- Task center (`tasks_center_rest.dart` → `GET /api/v1/projects`, `GET /api/v1/jobs/*`) ---

// --- Project list/CRUD compat (`projects_rest_compat.dart` → `/api/v1/projects`) ---

/// One **`app_novel`** row — OpenAPI **`NovelRow`**.
