FROM nimlang/nim:2.2.6-alpine-regular AS build
WORKDIR /app

# The build context is REPO_ROOT (as set in deploy.sh)
COPY . /app

# Install crown CLI globally
RUN nimble install -y

# Change to the website project
WORKDIR /app/website

# Install website dependencies and build the app
RUN nimble install -y
RUN crown build
RUN strip .crown/main

# Ensure public directory exists
RUN mkdir -p public

# Prepare runtime dependencies (PCRE)
FROM alpine:3.21 AS runtime-libs
RUN apk add --no-cache pcre

# Minimal scratch image
FROM scratch
WORKDIR /app
COPY --from=runtime-libs /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1
COPY --from=runtime-libs /usr/lib/libpcre.so.1* /usr/lib/
COPY --from=build /app/website/.crown/main /app/main
COPY --from=build /app/website/.env /app/.env
COPY --from=build /app/website/public /app/public

EXPOSE 8080
ENV PORT=8080
CMD ["/app/main"]
