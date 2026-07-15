# Stage 1: Build the Java application using Maven
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build

# Copy the pom.xml and source code
COPY pom.xml .
COPY src ./src

# Package the application (skipping tests for a quicker build)
RUN mvn clean package -DskipTests

# Stage 2: Package the application into Open Liberty
#FROM openliberty/open-liberty:kernel-java17-openj9
FROM icr.io/appcafe/open-liberty:kernel-java17-openj9-ubi

# Copy your server configuration (server.xml)
COPY --chown=1001:0 src/main/liberty/config/server.xml /config/

# Pre-install the Liberty features defined in your server.xml to optimize container startup time
RUN features.sh

# Copy the built .war file from the builder stage into the dropins directory
COPY --chown=1001:0 --from=builder /build/target/*.war /config/dropins/

# Run a preliminary startup check to populate the shared class cache
RUN configure.sh