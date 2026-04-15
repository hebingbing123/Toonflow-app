import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'core.dart';

export 'core.dart';
export 'agents/index.dart';
export 'catalog/index.dart';
export 'harness/index.dart';
export 'production.dart';
export 'project/visual_manual.dart';
export 'quality/index.dart';
export 'settings/index.dart';
export 'shared_kernel/index.dart';
export 'skills/index.dart';
export 'scripts/index.dart';
export 'system/index.dart';

part 'assets/api.dart';
part 'assets/crud.dart';
part 'assets/images.dart';
part 'assets/workbench/images.dart';
part 'assets/models/core.dart';
part 'assets/models/corner_scape.dart';
part 'assets/models/images.dart';
part 'assets/models/workbench_data.dart';
part 'assets/models/polling.dart';
part 'assets/generate.dart';
part 'jobs/api.dart';
part 'jobs/task_center.dart';
part 'novels/models.dart';
part 'novels/events_models.dart';
part 'novels/crud.dart';
part 'novels/workbench_http.dart';
part 'novels/rest_api.dart';
part 'novels/events.dart';
part 'project/overview.dart';
part 'project/manuals.dart';
part 'project/manuals_director.dart';
part 'project/manuals_visual.dart';
part 'project/rest.dart';
part 'project/compat.dart';

/// `POST /api/v1/production/get-production-data` — OpenAPI `postProductionGetProductionDataV1` (implemented in Rust; returns **200** or **503** without DB).

// --- Task center (`tasks_center_rest.dart` → `GET /api/v1/projects`, `GET /api/v1/jobs/*`) ---

// --- Project list/CRUD compat (`projects_rest_compat.dart` → `/api/v1/projects`) ---

/// One **`app_novel`** row — OpenAPI **`NovelRow`**.
