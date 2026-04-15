import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'core.dart';

export 'core.dart';
export 'agents/index.dart';
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

/// `POST /api/v1/production/get-production-data` — OpenAPI `postProductionGetProductionDataV1` (implemented in Rust; returns **200** or **503** without DB).

// --- Task center (`tasks_center_rest.dart` → `GET /api/v1/projects`, `GET /api/v1/jobs/*`) ---

// --- Project list/CRUD compat (`projects_rest_compat.dart` → `/api/v1/projects`) ---

/// One **`app_novel`** row — OpenAPI **`NovelRow`**.
