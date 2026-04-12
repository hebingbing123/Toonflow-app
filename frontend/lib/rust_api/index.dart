import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'core.dart';

export 'core.dart';
export 'production.dart';

part 'art_styles.dart';
part 'agent_memory_api.dart';
part 'assets/api.dart';
part 'assets/crud.dart';
part 'assets/images.dart';
part 'assets/models.dart';
part 'assets/generate.dart';
part 'catalog_memory_models.dart';
part 'harness_api.dart';
part 'jobs_api.dart';
part 'models_catalog.dart';
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
part 'prompts_api.dart';
part 'projects_rest_extra.dart';
part 'projects_rest_compat.dart';
part 'quality/models.dart';
part 'quality/api.dart';
part 'quality/stats.dart';
part 'scripts_api.dart';
part 'scripts_storyboards_models.dart';
part 'script_agent.dart';
part 'skills_binary_api.dart';
part 'skills_api.dart';
part 'settings/about_danger.dart';
part 'settings/agent_deploy.dart';
part 'settings/memory_config_api.dart';
part 'settings/vendor_credentials.dart';
part 'settings/vendors_mutations.dart';
part 'status_auth_me.dart';
part 'storyboards_api.dart';
part 'system_status_api.dart';
part 'tasks_center_rest.dart';
part 'usage_api.dart';
part 'visual_manual_api.dart';

/// `POST /api/v1/production/get-production-data` — OpenAPI `postProductionGetProductionDataV1` (implemented in Rust; returns **200** or **503** without DB).

// --- Task center (`tasks_center_rest.dart` → `GET /api/v1/projects`, `GET /api/v1/jobs/*`) ---

// --- Project list/CRUD compat (`projects_rest_compat.dart` → `/api/v1/projects`) ---

/// One **`app_novel`** row — OpenAPI **`NovelRow`**.
