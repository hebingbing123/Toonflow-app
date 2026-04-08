import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'core.dart';

export 'core.dart';
export 'production.dart';

part 'catalog_memory.dart';
part 'art_styles.dart';
part 'assets_api.dart';
part 'assets_generate.dart';
part 'harness_api.dart';
part 'jobs_api.dart';
part 'novels_models.dart';
part 'novels_api.dart';
part 'project_overview.dart';
part 'projects_legacy.dart';
part 'quality_reviews.dart';
part 'scripts_storyboards.dart';
part 'script_agent.dart';
part 'skills_api.dart';
part 'settings_admin.dart';
part 'status_and_auth.dart';
part 'tasks_legacy.dart';

/// `POST /api/v1/production/get-production-data` — OpenAPI `postProductionGetProductionDataV1` (implemented in Rust; returns **200** or **503** without DB).

// --- Legacy `POST /api/v1/tasks/*` (Electron task center) ---

// --- Legacy `POST /api/v1/project/*` (Electron project CRUD helpers) ---

/// One **`app_novel`** row — OpenAPI **`NovelRow`**.
