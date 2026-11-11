#!/bin/sh
# Download the model on first start, then run the server.
# A marker file is written after a full download, so restarts skip it and an
# interrupted download is resumed on the next start.
set -eu

export MODEL_REPO="${JEFF_MODEL_REPO:-knowledgator/gliformer-large-v1}"
export MODEL_REVISION="${JEFF_MODEL_REVISION:-main}"
MARKER="${JEFF_MODEL}/.download-complete"

if [ ! -f "$MARKER" ]; then
  echo "entrypoint: downloading ${MODEL_REPO}@${MODEL_REVISION} to ${JEFF_MODEL} (first start only)"
  python -c "
import os
from huggingface_hub import snapshot_download
snapshot_download(os.environ['MODEL_REPO'], revision=os.environ['MODEL_REVISION'], local_dir=os.environ['JEFF_MODEL'])
"
  touch "$MARKER"
fi

if [ -z "${JEFF_API_KEYS:-}" ]; then
  echo "entrypoint: WARNING JEFF_API_KEYS is empty, so the API has no authentication" >&2
fi

exec jeff
