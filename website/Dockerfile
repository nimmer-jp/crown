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

# Nim + Basolato with `-d:ssl` (Crown defaults) produces a dynamically linked ELF that
# expects musl libc, libpcre, OpenSSL (for TLS/session crypto), libgcc stack helpers, etc.
# A scratch image ships only libc + PCRE, so `/app/main` exits before bind — Cloud Run then
# reports PORT timeout. Alpine matches the Nim image libc and installs the loader + deps.
FROM alpine:3.21
WORKDIR /app
RUN apk add --no-cache \
    libgcc \
    pcre \
    openssl \
    ca-certificates
COPY --from=build /app/website/.crown/main /app/main
COPY --from=build /app/website/.env /app/.env
COPY --from=build /app/website/public /app/public

EXPOSE 8080
ENV PORT=8080
CMD ["/app/main"]
