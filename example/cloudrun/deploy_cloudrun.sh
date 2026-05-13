#!/usr/bin/env bash
# Google Cloud Run へ Crown アプリのコンテナをデプロイするサンプル。
#
# 前提: gcloud / Docker（必要なら buildx）が使えること。
#
# 使い方:
#   1. 下記の既定値を自分の GCP プロジェクト・リージョン・サービス名に合わせるか、
#      アプリのルートに .env を置き PROJECT_ID / REGION / CLOUD_RUN_SERVICE などを定義する。
#   2. このスクリプトがあるディレクトリから実行:
#        bash deploy_cloudrun.sh
#      または実行権限を付けて ./deploy_cloudrun.sh
#
# Artifact Registry のリポジトリ名はサービス名と別でも構いません。
# 複数アプリで共有する場合は ARTIFACT_REGISTRY_REPO を変えてください。

set -euo pipefail

# --- 環境（必要に応じて書き換え、または .env で上書き） ---
: "${PROJECT_ID:=your-gcp-project-id}"
: "${REGION:=asia-northeast1}"
: "${CLOUD_RUN_SERVICE:=crown-app}"
: "${ARTIFACT_REGISTRY_REPO:=crown-apps}"
: "${IMAGE_TAG:=latest}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${APP_ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${APP_ROOT}/.env"
  set +a
fi

IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/${CLOUD_RUN_SERVICE}:${IMAGE_TAG}"

if [[ "${PROJECT_ID}" == "your-gcp-project-id" ]]; then
  echo "PROJECT_ID が既定値のままです。スクリプト先頭の変数か ${APP_ROOT}/.env を設定してください。" >&2
  exit 1
fi

gcloud config set project "${PROJECT_ID}"

gcloud artifacts repositories create "${ARTIFACT_REGISTRY_REPO}" \
  --repository-format=docker \
  --location="${REGION}" \
  2>/dev/null || true

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

docker buildx build \
  --platform linux/amd64 \
  -f "${SCRIPT_DIR}/Dockerfile" \
  -t "${IMAGE_URI}" \
  "${APP_ROOT}"

docker push "${IMAGE_URI}"

gcloud run deploy "${CLOUD_RUN_SERVICE}" \
  --image="${IMAGE_URI}" \
  --platform=managed \
  --region="${REGION}" \
  --allow-unauthenticated \
  --port=8080

echo "Deployed: ${CLOUD_RUN_SERVICE} (${REGION}) image ${IMAGE_URI}"
