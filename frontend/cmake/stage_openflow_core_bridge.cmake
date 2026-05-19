if(NOT DEFINED REPO_ROOT)
  message(FATAL_ERROR "REPO_ROOT is required")
endif()

if(NOT DEFINED CONFIG)
  set(CONFIG Debug)
endif()

if(NOT DEFINED TARGET_DIR)
  message(FATAL_ERROR "TARGET_DIR is required")
endif()

if(NOT DEFINED TARGET_OS)
  message(FATAL_ERROR "TARGET_OS is required")
endif()

set(RUST_MANIFEST_PATH "${REPO_ROOT}/rust_core/Cargo.toml")
set(CARGO_PROFILE_DIR debug)
set(CARGO_ARGS)

if(NOT CONFIG STREQUAL "Debug")
  set(CARGO_PROFILE_DIR release)
  list(APPEND CARGO_ARGS --release)
endif()

if(TARGET_OS STREQUAL "windows")
  set(LIB_FILE_NAME "openflow_core_bridge.dll")
elseif(TARGET_OS STREQUAL "linux")
  set(LIB_FILE_NAME "libopenflow_core_bridge.so")
else()
  message(FATAL_ERROR "Unsupported TARGET_OS=${TARGET_OS}")
endif()

execute_process(
  COMMAND cargo build --manifest-path "${RUST_MANIFEST_PATH}" -p openflow_core_bridge ${CARGO_ARGS}
  WORKING_DIRECTORY "${REPO_ROOT}"
  COMMAND_ERROR_IS_FATAL ANY
)

set(RUST_LIB_PATH "${REPO_ROOT}/rust_core/target/${CARGO_PROFILE_DIR}/${LIB_FILE_NAME}")
if(NOT EXISTS "${RUST_LIB_PATH}")
  message(FATAL_ERROR "Expected Rust bridge at ${RUST_LIB_PATH}")
endif()

file(MAKE_DIRECTORY "${TARGET_DIR}")
file(COPY "${RUST_LIB_PATH}" DESTINATION "${TARGET_DIR}")
