# CPU-only image for jeff. Used by technologiestiftung/ds-root-server (service `jeff`).
#
# Why the install is split in two steps:
# - The lockfile pins torch from PyPI. On Linux that pulls the CUDA build plus about
#   15 nvidia-* packages, several GB the servers can't use (they have no GPU).
# - So we export the locked versions, drop the nvidia/triton lines, and let uv fetch
#   torch from the PyTorch CPU index (`--torch-backend=cpu`). Versions stay as locked.
#
# The model weights are NOT in the image. entrypoint.sh downloads them on first start
# into /models, which the compose file mounts as a volume.

FROM python:3.12-slim

COPY --from=ghcr.io/astral-sh/uv:0.11.23 /uv /usr/local/bin/uv

ENV PYTHONUNBUFFERED=1 \
    UV_SYSTEM_PYTHON=1 \
    UV_NO_CACHE=1 \
    HF_HOME=/models/.hf \
    JEFF_MODEL=/models/gliformer-large-v1 \
    JEFF_DEVICE=cpu \
    JEFF_PORT=8000

WORKDIR /app

# 1. Dependencies only (cached until pyproject.toml or uv.lock change).
COPY pyproject.toml uv.lock README.md ./
RUN uv export --frozen --no-dev --extra onnx --no-emit-project --no-hashes --no-annotate -o /tmp/req.txt \
 && grep -vE '^(nvidia-|triton)' /tmp/req.txt > /tmp/req-cpu.txt \
 && uv pip install --torch-backend=cpu -r /tmp/req-cpu.txt \
 && rm /tmp/req*.txt

# 2. The app itself, without touching the dependencies again.
COPY src ./src
RUN uv pip install --no-deps .

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Run as a normal user. /models is created here so a Docker named volume mounted
# on it inherits this owner and the download can write to it.
RUN chmod +x /usr/local/bin/entrypoint.sh \
 && useradd --create-home --uid 1000 jeff \
 && mkdir -p /models && chown jeff:jeff /models
USER jeff

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10m --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=4).status == 200 else 1)"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
