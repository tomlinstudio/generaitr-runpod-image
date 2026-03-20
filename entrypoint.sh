#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${COMFYUI_STATE_DIR:-/workspace/comfyui-state}"
LISTEN_HOST="${COMFYUI_LISTEN_HOST:-0.0.0.0}"
PORT="${COMFYUI_PORT:-8190}"
USE_SAGE_ATTENTION="${COMFYUI_USE_SAGE_ATTENTION:-0}"
SYNC_REPO_URL="${GENERAITR_SYNC_REPO_URL:-}"
SYNC_REPO_REF="${GENERAITR_SYNC_REPO_REF:-main}"
SYNC_SCRIPTS_DIR="${GENERAITR_SYNC_SCRIPTS_DIR:-scripts}"
WORKSPACE_SCRIPTS_DIR="${GENERAITR_WORKSPACE_SCRIPTS_DIR:-/workspace/scripts}"
PREPARE_SCRIPTS_ONLY="${GENERAITR_PREPARE_SCRIPTS_ONLY:-0}"
MODEL_PATHS_CONFIG="${COMFYUI_MODEL_PATHS_CONFIG:-${STATE_DIR}/extra_model_paths.yaml}"
AUTO_BOOTSTRAP_FRESH_NODE="${GENERAITR_AUTO_BOOTSTRAP_FRESH_NODE:-0}"
BOOTSTRAP_FRESH_NODE_SCRIPT="${GENERAITR_BOOTSTRAP_FRESH_NODE_SCRIPT:-/workspace/scripts/bootstrap_runpod_fresh.sh}"

if [ -n "${SYNC_REPO_URL}" ]; then
  SCRIPTS_MARKER="${WORKSPACE_SCRIPTS_DIR}/.generaitr_managed"
  SCRIPTS_OLD_DIR="${WORKSPACE_SCRIPTS_DIR}/old"

  mkdir -p "${WORKSPACE_SCRIPTS_DIR}"

  if [ ! -f "${SCRIPTS_MARKER}" ] && find "${WORKSPACE_SCRIPTS_DIR}" -mindepth 1 -not -path "${SCRIPTS_OLD_DIR}" -print -quit | grep -q .; then
    ARCHIVE_DIR="${SCRIPTS_OLD_DIR}/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${ARCHIVE_DIR}"
    find "${WORKSPACE_SCRIPTS_DIR}" -mindepth 1 -maxdepth 1 ! -name old -exec mv {} "${ARCHIVE_DIR}/" \;
  fi

  TMP_REPO_DIR="$(mktemp -d)"
  git clone --depth 1 --branch "${SYNC_REPO_REF}" --filter=blob:none --sparse "${SYNC_REPO_URL}" "${TMP_REPO_DIR}"
  (
    cd "${TMP_REPO_DIR}"
    git sparse-checkout set "${SYNC_SCRIPTS_DIR}"
  )
  if [ -d "${TMP_REPO_DIR}/${SYNC_SCRIPTS_DIR}" ]; then
    cp -a "${TMP_REPO_DIR}/${SYNC_SCRIPTS_DIR}/." "${WORKSPACE_SCRIPTS_DIR}/"
    touch "${SCRIPTS_MARKER}"
  fi
  rm -rf "${TMP_REPO_DIR}"
fi

mkdir -p \
  "${STATE_DIR}/input" \
  "${STATE_DIR}/output" \
  "${STATE_DIR}/temp" \
  "${STATE_DIR}/user" \
  "${STATE_DIR}/models"

cat > "${MODEL_PATHS_CONFIG}" <<EOF
generaitr:
  base_path: ${STATE_DIR}
  checkpoints: models/checkpoints
  text_encoders: |
    models/text_encoders
    models/clip
  clip_vision: models/clip_vision
  configs: models/configs
  controlnet: models/controlnet
  diffusion_models: |
    models/diffusion_models
    models/unet
  embeddings: models/embeddings
  loras: models/loras
  upscale_models: models/upscale_models
  vae: models/vae
  audio_encoders: models/audio_encoders
  model_patches: models/model_patches
EOF

if [ "${AUTO_BOOTSTRAP_FRESH_NODE}" = "1" ] && [ -f "${BOOTSTRAP_FRESH_NODE_SCRIPT}" ]; then
  bash "${BOOTSTRAP_FRESH_NODE_SCRIPT}"
fi

if [ "${PREPARE_SCRIPTS_ONLY}" = "1" ]; then
  exit 0
fi

cd /opt/generaitr/comfyui

EXTRA_ARGS=()
case "${USE_SAGE_ATTENTION}" in
  1|true|TRUE|yes|YES)
    EXTRA_ARGS+=(--use-sage-attention)
    ;;
esac

exec python main.py \
  --listen "${LISTEN_HOST}" \
  --port "${PORT}" \
  --extra-model-paths-config "${MODEL_PATHS_CONFIG}" \
  --input-directory "${STATE_DIR}/input" \
  --output-directory "${STATE_DIR}/output" \
  --temp-directory "${STATE_DIR}/temp" \
  --user-directory "${STATE_DIR}/user" \
  --force-fp16 \
  --fast \
  "${EXTRA_ARGS[@]}" \
  "$@"
