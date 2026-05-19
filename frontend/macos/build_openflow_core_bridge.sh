#!/bin/sh
set -eu

REPO_ROOT="$(cd "${PROJECT_DIR}/../.." && pwd)"
RUST_MANIFEST_PATH="${REPO_ROOT}/rust_core/Cargo.toml"
FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
LIB_NAME="libopenflow_core_bridge.dylib"

CARGO_PROFILE_DIR="debug"
CARGO_ARGS=""
if [ "${CONFIGURATION}" != "Debug" ]; then
  CARGO_PROFILE_DIR="release"
  CARGO_ARGS="--release"
fi

cargo build --manifest-path "${RUST_MANIFEST_PATH}" -p openflow_core_bridge ${CARGO_ARGS}

SOURCE_LIB="${REPO_ROOT}/rust_core/target/${CARGO_PROFILE_DIR}/${LIB_NAME}"
DEST_LIB="${FRAMEWORKS_DIR}/${LIB_NAME}"

mkdir -p "${FRAMEWORKS_DIR}"
cp "${SOURCE_LIB}" "${DEST_LIB}"
install_name_tool -id "@rpath/${LIB_NAME}" "${DEST_LIB}"

if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ] && [ "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]; then
  codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --timestamp=none "${DEST_LIB}"
fi
