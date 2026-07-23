# syntax=docker/dockerfile:1

# Stage 1: Build the Java application using Maven
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build

# Copy the pom.xml and source code
COPY pom.xml .
COPY src ./src

# Package the application (skipping tests for a quicker build).
# Cache the local repo across builds so unrelated source changes don't force
# every dependency to be re-downloaded (the builder container is reused, see Jenkinsfile).
RUN --mount=type=cache,target=/root/.m2 mvn clean package -DskipTests

# Stage 2: Package the application into Open Liberty
FROM icr.io/appcafe/open-liberty:kernel-slim-java21-openj9-ubi-minimal

# Copy your server configuration (server.xml)
COPY --chown=1001:0 server.xml /config/

# Pre-install the Liberty features defined in your server.xml to optimize container startup time
RUN features.sh

# Copy the built .war file from the builder stage into apps/, where a relative <webApplication location="..."/> resolves
COPY --chown=1001:0 --from=builder /build/target/*.war /config/apps/

# Run a preliminary startup check to populate the shared class cache
RUN configure.sh