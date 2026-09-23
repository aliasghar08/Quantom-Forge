FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Requirements first, on their own layer: torch is a few hundred MB and the
# code above it changes far more often than the dependencies do.
COPY requirements.txt ./
RUN pip install --upgrade pip && pip install -r requirements.txt

# The checkpoint is baked into the image rather than fetched at boot. It is
# 2.2 MB and tracked in git, so it is already in the build context, and baking it
# in removes any dependence on a mounted disk, a download step, or a working
# directory that happens to sit next to the file.
COPY main.py ./
COPY t1x_model_checkpoint.pt ./

ENV T1X_CHECKPOINT=/app/t1x_model_checkpoint.pt
ENV PORT=8000

EXPOSE 8000

# Readiness, not just liveness: the check fails when the checkpoint did not
# load, so a deploy whose model is broken is reported instead of serving 503s
# from a container that looks fine.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD python -c "import json,os,sys,urllib.request as u; d=json.load(u.urlopen('http://127.0.0.1:'+os.environ.get('PORT','8000')+'/health',timeout=4)); sys.exit(0 if d.get('model_loaded') else 1)"

# ${PORT} is what Render and most PaaS platforms inject; 8000 is the local default.
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
