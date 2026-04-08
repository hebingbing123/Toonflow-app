import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'core.dart';

export 'core.dart';
export 'production.dart';

part 'art_styles.dart';
part 'agent_memory_api.dart';
part 'assets_api.dart';
part 'assets_crud.dart';
part 'assets_images.dart';
part 'assets_models.dart';
part 'assets_generate.dart';
part 'catalog_memory_models.dart';
part 'harness_api.dart';
part 'jobs_api.dart';
part 'models_catalog.dart';
part 'novels_models.dart';
part 'novels_events_models.dart';
part 'novels_crud.dart';
part 'novels_legacy_api.dart';
part 'novels_rest_api.dart';
part 'novels_events.dart';
part 'project_overview.dart';
part 'project_manuals.dart';
part 'project_manuals_director.dart';
part 'project_manuals_visual.dart';
part 'prompts_api.dart';
part 'projects_legacy.dart';
part 'projects_legacy_compat.dart';
part 'quality_reviews.dart';
part 'quality_reviews_api.dart';
part 'quality_reviews_stats.dart';
part 'scripts_api.dart';
part 'scripts_storyboards_models.dart';
part 'script_agent.dart';
part 'skills_binary_api.dart';
part 'skills_api.dart';
part 'settings_about_danger.dart';
part 'settings_agent_deploy.dart';
part 'settings_memory_config_api.dart';
part 'settings_vendors_mutations.dart';
part 'status_auth_me.dart';
part 'storyboards_api.dart';
part 'system_status_api.dart';
part 'tasks_legacy.dart';
part 'usage_api.dart';
part 'visual_manual_api.dart';

/// `POST /api/v1/production/get-production-data` — OpenAPI `postProductionGetProductionDataV1` (implemented in Rust; returns **200** or **503** without DB).

// --- Legacy `POST /api/v1/tasks/*` (Electron task center) ---

// --- Legacy `POST /api/v1/project/*` (Electron project CRUD helpers) ---

/// One **`app_novel`** row — OpenAPI **`NovelRow`**.
