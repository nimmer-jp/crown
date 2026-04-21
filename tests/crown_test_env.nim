## Sets env vars before any module that imports Basolato is initialized (see tcrown_route_register).
import std/os

putEnv("SECRET_KEY", "crown-test-secret-key-32chars-min____")

const crownTestsEnvReady* = true
