# Crown アプリケーションを Google Cloud Run 向けにマルチステージビルドするサンプル。
#
# ビルド方法（このリポジトリの example の場合）:
#   docker build -f cloudrun/Dockerfile -t crown-example:local ..
#
# 一般的には Crown プロジェクトのルートをコンテキストにし、この Dockerfile のパスだけ合わせてください。
# アプリ直下の nim.cfg が ../src など「開発マシン専用」の --path を含む場合は、
# コンテナでは Crown を nimble で入れる想定のため .dockerignore で nim.cfg を除外するか、
# イメージに含めない運用にしてください。

FROM nimlang/nim:2.2.8 AS builder

WORKDIR /app

COPY *.nimble ./
COPY crown.json ./
COPY src ./src
COPY public ./public

RUN nimble install -y --depsOnly \
  && nimble install -y crown \
  && mkdir -p .crown \
  && HOST=0.0.0.0 PORT=8080 crown build

FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    libpcre3 \
    libssl3 \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --system --no-create-home --uid 65532 crownapp

WORKDIR /app

COPY --from=builder /app/public ./public
COPY --from=builder /app/.crown/main /app/server

USER crownapp

ENV HOST=0.0.0.0
ENV PORT=8080
ENV LOG_IS_FILE=false
ENV LOG_IS_ERROR_FILE=false

EXPOSE 8080

CMD ["/app/server"]
