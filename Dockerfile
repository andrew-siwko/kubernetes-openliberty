# syntax=docker/dockerfile:1

# Stage 1: Build the Java application using Maven
FROM maven:3.9-eclipse-temurin-25 AS builder
WORKDIR /build

# Copy the pom.xml and source code
COPY pom.xml .
COPY src ./src

# Package the application (skipping tests for a quicker build).
# Cache the local repo across builds so unrelated source changes don't force
# every dependency to be re-downloaded (the builder container is reused, see Jenkinsfile).
RUN --mount=type=cache,target=/root/.m2 mvn clean package -DskipTests

# Stage 2: Package the application into Open Liberty
FROM icr.io/appcafe/open-liberty:kernel-slim-java25-openj9-ubi-minimal

# Copy your server configuration (server.xml)
COPY --chown=1001:0 server.xml /config/

# Pre-install the Liberty features defined in your server.xml to optimize container startup time
RUN features.sh

# Copy the built .war file from the builder stage into apps/, where a relative <webApplication location="..."/> resolves
COPY --chown=1001:0 --from=builder /build/target/*.war /config/apps/

# Run a preliminary startup check to populate the shared class cache.
# Skipped when cross-building (Jenkinsfile's buildx run targets both amd64
# and arm64 from an amd64 builder, so the arm64 leg runs under QEMU
# user-mode emulation) -- confirmed live, OpenJ9's persistent shared class
# cache relies on mmap/shared-memory semantics QEMU doesn't emulate
# reliably, and configure.sh (which actually starts/stops the server to
# populate it, unlike features.sh above) crashes with exit code 21 after
# ~200s under emulation. It's a startup-time optimization, not required for
# correctness -- Liberty just builds the cache lazily on first real start
# instead, same as it already does non-emulated on amd64.
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN if [ "$TARGETPLATFORM" = "$BUILDPLATFORM" ]; then configure.sh; fi