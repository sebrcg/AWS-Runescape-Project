FROM eclipse-temurin:8-jdk AS builder
WORKDIR /app

# Copy build tooling first to leverage Docker layer caching
COPY gradlew gradlew
COPY gradle gradle
COPY build.gradle.kts settings.gradle.kts ./

# gradlew can lose its executable bit on a fresh checkout (Git on Windows doesn't
# track Unix permissions), so make it runnable before we invoke it.
RUN chmod +x gradlew

# Download dependencies (cached layer - rarely changes)
RUN ./gradlew --no-daemon dependencies

# Copy sources and build (changes more frequently)
COPY src src
RUN ./gradlew --no-daemon classes installDist

# Runtime stage
FROM eclipse-temurin:8-jdk
WORKDIR /app

# Copy compiled application from builder
COPY --from=builder /app/build /app/build

# Copy static game data (cache + resources) into image for fast startup
# These rarely change, so this layer will be cached
COPY data/cache /app/data/cache
COPY data/resource /app/data/resource

# Create directories for dynamic data (will be mounted or stored in volumes)
RUN mkdir -p /opt/lotica/data /opt/lotica/backups

# Expose default game and js5 ports
EXPOSE 43594 43595

# Tweak memory via JAVA_TOOL_OPTIONS or override at runtime
ENV JAVA_TOOL_OPTIONS="-Xms1g -Xmx1g -Xss4m"

# Run the prebuilt distribution
ENTRYPOINT ["/app/build/install/Lotica/bin/Lotica"]

