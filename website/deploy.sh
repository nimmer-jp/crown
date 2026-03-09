#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$SCRIPT_DIR"

PROJECT_ID="${PROJECT_ID:-pianopia}"
PRODUCT_ID="${PRODUCT_ID:-crown}"
REGION="${REGION:-asia-northeast1}"

IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${PRODUCT_ID}/${PRODUCT_ID}:latest"

gcloud config set project "$PROJECT_ID"

if ! gcloud artifacts repositories describe "$PRODUCT_ID" --location="$REGION" >/dev/null 2>&1; then
  gcloud artifacts repositories create "$PRODUCT_ID" \
    --repository-format=docker \
    --location="$REGION" \
    --description="Frontend Docker images"
fi

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

docker buildx build \
  -f "$SCRIPT_DIR/Dockerfile" \
  -t "$IMAGE" \
  --platform linux/amd64 \
  --load \
  "$REPO_ROOT"

docker push "$IMAGE"

gcloud run deploy "$PRODUCT_ID" \
  --image "$IMAGE" \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars NODE_ENV=production \
  --region "$REGION"

gcloud run services update-traffic "$PRODUCT_ID" \
  --to-latest \
  --region "$REGION"
