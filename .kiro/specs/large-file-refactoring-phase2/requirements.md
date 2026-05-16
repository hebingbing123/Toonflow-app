# Requirements Document

## Introduction

This feature systematically refactors 18 oversized files (13 Rust backend, 5 Flutter frontend) to comply with the ≤800-line standard defined in AGENTS.md. The files range from 802 to 3164 lines. The refactoring strategy is: analyze each file → design a cohesive module split → execute the split → run the refactor-check.sh gate → commit incrementally. All public APIs (OpenAPI, WebSocket) must remain intact throughout.

## Glossary

- **Refactoring_System**: The automated pipeline that analyzes, splits, validates, and commits oversized files.
- **File_Analyzer**: The component that parses a source file and identifies natural split boundaries.
- **Module_Splitter**: The component that creates new module files and moves code from the source file.
- **Gate_Validator**: The component that runs `refactor-check.sh` (cargo fmt, clippy, test; flutter analyze, test; OpenAPI validation).
- **Incremental_Committer**: The component that stages and commits changes after each successful file split.
- **Target_File**: Any source file in the refactoring set that currently exceeds 800 lines.
- **Module**: A new source file created by splitting a Target_File; must be ≤800 lines.
- **Re-export_File**: The original file path after splitting, containing only `pub use` / `export` statements that re-expose all previously public symbols.
- **Public_API**: The set of all public functions, types, and constants exported by a Target_File before refactoring.
- **Gate_Check**: Execution of `scripts/refactor-check.sh` (or equivalent per-language subset) that must pass before a commit is created.
- **Dependency_Graph**: The directed graph of `use`/`import` relationships between Modules created from a single Target_File.
- **Rollback**: Deletion of all created Modules and restoration of the Target_File to its pre-split state.
- **Batch**: The complete set of 18 Target_Files processed in a single refactoring run.

---

## Requirements

### Requirement 1: Module Size Compliance

**User Story:** As a developer, I want every refactored module to be ≤800 lines, so that the codebase complies with the AGENTS.md maintainability standard.

#### Acceptance Criteria

1. WHEN a Target_File is split, THE Module_Splitter SHALL produce Modules such that every Module contains ≤800 lines.
2. WHEN a Target_File is split, THE Module_Splitter SHALL produce a Re-export_File that also contains ≤800 lines.
3. THE Refactoring_System SHALL process Target_Files in descending order of line count (largest first).
4. WHEN all Target_Files in the Batch have been processed, THE Refactoring_System SHALL report the total number of lines brought into compliance.

---

### Requirement 2: Line Count Conservation

**User Story:** As a developer, I want the total lines across all Modules to equal the original file's line count (within a small tolerance), so that no code is accidentally lost or duplicated during splitting.

#### Acceptance Criteria

1. WHEN a Target_File is split into Modules, THE Module_Splitter SHALL ensure the sum of all Module line counts is within ±10 lines of the original Target_File line count.
2. THE Module_Splitter SHALL NOT duplicate any function, type, or constant across multiple Modules.
3. THE Module_Splitter SHALL NOT omit any function, type, or constant that existed in the Target_File.

---

### Requirement 3: Public API Preservation

**User Story:** As a developer, I want all previously public symbols to remain accessible after refactoring, so that no dependent code breaks.

#### Acceptance Criteria

1. WHEN a Target_File is split, THE Module_Splitter SHALL create a Re-export_File at the original file path that re-exports every symbol that was public before the split.
2. WHEN a Target_File is split, THE Refactoring_System SHALL verify that the Public_API before splitting is a subset of the Public_API accessible after splitting.
3. WHEN a backend Target_File is split, THE Gate_Validator SHALL confirm the OpenAPI specification remains parseable and unchanged in contract by running `cargo run --bin export-openapi`.
4. IF a public symbol is missing from the Re-export_File, THEN THE Module_Splitter SHALL abort the split and trigger a Rollback.

---

### Requirement 4: Dependency Acyclicity

**User Story:** As a developer, I want no circular dependencies between the Modules created from a single file, so that the build system can compile them without errors.

#### Acceptance Criteria

1. WHEN a Target_File is split, THE File_Analyzer SHALL verify that the resulting Dependency_Graph contains no cycles before any files are written.
2. IF a cycle is detected in the proposed Dependency_Graph, THEN THE Refactoring_System SHALL abort the split, log the cycle details, and add the Target_File to the failed list.
3. WHEN a split is executed, THE Module_Splitter SHALL arrange module declarations so that each Module only imports from Modules that do not import back from it.

---

### Requirement 5: Dependent File Import Updates

**User Story:** As a developer, I want all files that import from a refactored file to have their imports updated automatically, so that the codebase compiles without manual intervention.

#### Acceptance Criteria

1. WHEN a Target_File is split, THE Module_Splitter SHALL identify all files in the repository that import from the Target_File.
2. WHEN a Target_File is split, THE Module_Splitter SHALL update the import statements in every dependent file to reference the correct new Module or Re-export_File.
3. WHEN import updates are applied, THE Gate_Validator SHALL confirm all dependent files compile successfully as part of the Gate_Check.

---

### Requirement 6: Gate Check Enforcement

**User Story:** As a developer, I want every split to pass the full quality gate before being committed, so that the repository always stays in a green state.

#### Acceptance Criteria

1. WHEN a Target_File split is complete, THE Gate_Validator SHALL run `scripts/refactor-check.sh` before any commit is created.
2. WHEN only backend files are modified, THE Gate_Validator SHALL run `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`, and OpenAPI validation.
3. WHEN only frontend files are modified, THE Gate_Validator SHALL run `flutter pub get`, `flutter analyze`, and `flutter test`.
4. WHEN both backend and frontend files are modified, THE Gate_Validator SHALL run all backend and frontend checks.
5. IF the Gate_Check fails, THEN THE Refactoring_System SHALL NOT create a commit and SHALL trigger a Rollback of the split.
6. WHEN the Gate_Check passes, THE Incremental_Committer SHALL create a commit before processing the next Target_File.

---

### Requirement 7: Atomicity and Rollback

**User Story:** As a developer, I want a failed split to leave the repository in exactly its pre-split state, so that partial refactorings never corrupt the codebase.

#### Acceptance Criteria

1. WHEN a split fails at any stage (file creation, import update, or Gate_Check), THE Refactoring_System SHALL delete all Modules created during that split.
2. WHEN a split fails at any stage, THE Refactoring_System SHALL restore the Target_File to its exact pre-split content.
3. WHEN a split fails at any stage, THE Refactoring_System SHALL restore all dependent files to their exact pre-split content.
4. AFTER a Rollback completes, THE Refactoring_System SHALL verify the git working directory is clean (no uncommitted changes).
5. WHEN a Rollback itself fails, THE Refactoring_System SHALL log the failure details and halt processing of subsequent files.

---

### Requirement 8: Incremental Commits

**User Story:** As a developer, I want one focused commit per successfully refactored file, so that the git history is readable and each change is independently revertable.

#### Acceptance Criteria

1. WHEN a Target_File is successfully split and the Gate_Check passes, THE Incremental_Committer SHALL create exactly one commit containing all files modified or created during that split.
2. THE Incremental_Committer SHALL use a commit message that includes the original file path, the number of Modules created, and the line count reduction (e.g., `refactor(backend): split publish/store.rs into 6 modules (1345→100 lines)`).
3. THE Incremental_Committer SHALL stage only the files modified or created during the current split, not unrelated changes.
4. IF a git commit cannot be created (dirty working directory, conflicts), THEN THE Refactoring_System SHALL log the error and prompt the user to resolve git issues before continuing.

---

### Requirement 9: Batch Progress Tracking

**User Story:** As a developer, I want to see the progress of the full batch refactoring, so that I can monitor completion and identify any files that need manual attention.

#### Acceptance Criteria

1. THE Refactoring_System SHALL track and report the count of completed files, failed files, and remaining files throughout the Batch.
2. WHEN the Batch completes, THE Refactoring_System SHALL report: total files processed, files successfully refactored, files failed, total lines reduced, and list of commit hashes created.
3. WHEN a Target_File fails refactoring, THE Refactoring_System SHALL record the file path, error message, Gate_Check failures, and retry count in the progress report.
4. THE Refactoring_System SHALL ensure that for every Batch: `completedFiles + failedFiles.length = totalFiles`.

---

### Requirement 10: File Analysis

**User Story:** As a developer, I want the system to automatically analyze each oversized file and recommend a split strategy, so that the split boundaries are cohesive and maintainable.

#### Acceptance Criteria

1. WHEN analyzing a Rust (.rs) Target_File, THE File_Analyzer SHALL parse all function signatures, struct definitions, impl blocks, and import statements.
2. WHEN analyzing a Dart (.dart) Target_File, THE File_Analyzer SHALL parse all class definitions, methods, mixins, and import statements.
3. THE File_Analyzer SHALL group related functions by shared dependencies and assign a cohesion score in the range [0.0, 1.0] to each group.
4. THE File_Analyzer SHALL recommend a split strategy (HandlerGrouping, StoreOperations, UIComponentExtraction, or StateManagement) appropriate for the file type and content.
5. IF a Target_File cannot be parsed (syntax errors, unsupported constructs), THEN THE File_Analyzer SHALL skip the file, log the parse error, and add it to the failed list without attempting a split.

---

### Requirement 11: Specific File Split Plans

**User Story:** As a developer, I want each of the 18 Target_Files to be split according to the detailed plans in the design document, so that the resulting module structure is consistent and purposeful.

#### Acceptance Criteria

1. WHEN splitting `frontend/lib/short_video_space/section.dart` (3164 lines), THE Module_Splitter SHALL produce 7 Modules: `section.dart`, `section_state.dart`, `section_project.dart`, `section_production.dart`, `section_publish.dart`, `section_publish_scheduling.dart`, and `section_publish_copy.dart`, each ≤800 lines.
2. WHEN splitting `frontend/lib/short_video_space/view.dart` (2376 lines), THE Module_Splitter SHALL produce 8 Modules: `view.dart` plus 7 extracted widget component files, each ≤800 lines.
3. WHEN splitting `backend/src/publish/store.rs` (1345 lines), THE Module_Splitter SHALL produce 6 Modules: `store.rs` (re-exports) plus `profile_store.rs`, `draft_store.rs`, `target_store.rs`, `job_store.rs`, and `metric_store.rs`, each ≤800 lines.
4. WHEN splitting `backend/src/publish/handlers.rs` (1100 lines), THE Module_Splitter SHALL produce 6 Modules: `handlers.rs` (router + re-exports) plus `profile_handlers.rs`, `draft_handlers.rs`, `target_handlers.rs`, `job_handlers.rs`, and `audit_handlers.rs`, each ≤800 lines.
5. WHEN splitting `frontend/lib/short_video_space/support.dart` (1243 lines), THE Module_Splitter SHALL produce 5 Modules: `support.dart` (re-exports) plus `support_models.dart`, `support_project_api.dart`, `support_production_api.dart`, and `support_publish_api.dart`, each ≤800 lines.
6. WHEN splitting `backend/src/publish/adapters.rs` (1057 lines), THE Module_Splitter SHALL produce 6 Modules: `adapters.rs` (trait + re-exports) plus one file per platform adapter (Douyin, Kuaishou, Xiaohongshu, Bilibili, WeChat Channels), each ≤800 lines.
7. WHEN splitting the remaining 12 medium-priority Target_Files (802–1035 lines), THE Module_Splitter SHALL produce Modules according to the split strategies defined in the design document, with each Module ≤800 lines.

---

### Requirement 12: Execution Phases

**User Story:** As a developer, I want the refactoring to proceed in the three phases defined in the design, so that the highest-risk files are addressed first and progress is predictable.

#### Acceptance Criteria

1. THE Refactoring_System SHALL execute Phase 1 (critical frontend files: `section.dart`, `view.dart`, `support.dart`) before Phase 2.
2. THE Refactoring_System SHALL execute Phase 2 (critical backend files: `store.rs`, `handlers.rs`, `adapters.rs`, `observation_style.rs`) before Phase 3.
3. THE Refactoring_System SHALL execute Phase 3 (all remaining 11 medium-priority files) last.
4. WHEN all three phases complete, THE Refactoring_System SHALL verify that all 18 Target_Files have been processed and report final success metrics.

---

### Requirement 13: Code Integrity During Split

**User Story:** As a developer, I want function documentation, attributes, and formatting to be preserved exactly when code is moved to a new Module, so that no information is lost and the code remains readable.

#### Acceptance Criteria

1. WHEN THE Module_Splitter moves a function to a new Module, THE Module_Splitter SHALL preserve the complete function body, all doc comments, all attributes (e.g., `#[derive]`, `#[test]`, `@override`), and original formatting.
2. WHEN THE Module_Splitter moves a function to a new Module, THE Module_Splitter SHALL preserve the original order of functions as they appeared in the Target_File.
3. THE Module_Splitter SHALL resolve and include all imports required by the moved functions in the new Module file.
4. WHEN a Module is created, THE Gate_Validator SHALL confirm the Module compiles without errors as part of the Gate_Check.

---

### Requirement 14: Retry and Error Recovery

**User Story:** As a developer, I want the system to retry failed splits with adjusted strategies before giving up, so that transient or fixable errors do not permanently block a file.

#### Acceptance Criteria

1. WHEN a split fails due to a Gate_Check error, THE Refactoring_System SHALL analyze the error output and attempt the split again with adjusted module boundaries, up to a maximum of 3 retries.
2. WHEN a split fails due to a circular dependency, THE Refactoring_System SHALL suggest merging the conflicting Modules and log the dependency cycle details.
3. WHEN a split fails due to a missing re-export, THE Refactoring_System SHALL add the missing `pub use` / `export` statement and retry the Gate_Check without re-splitting.
4. IF a Target_File fails after 3 retries, THEN THE Refactoring_System SHALL add it to the failed list with full error details and continue processing the remaining Target_Files.
