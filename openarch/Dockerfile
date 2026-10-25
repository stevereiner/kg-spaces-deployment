# syntax=docker/dockerfile:1
#
# Hyland OpenArch, stock, built from its public GitHub repository at a commit (scripts/build-openarch.sh): for a
# commit newer than Hyland's published image (ghcr.io/hyland/openarch-app-jvm), which compose.openarch.yaml uses by
# default. Configured the same way (OPENSEARCH_ADDRESSLIST, NUXEO_MONGODB_SERVER, ... in compose.openarch.yaml) and
# running as the same user (uid 33010, gid 1000), so either image works on the same volumes.

# ----- build -----
FROM maven:3-eclipse-temurin-25 AS build

RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

WORKDIR /build

ARG OPENARCH_GIT_URL=https://github.com/Hyland/OpenArch.git
ARG OPENARCH_GIT_REF
RUN test -n "$OPENARCH_GIT_REF" || (echo "OPENARCH_GIT_REF is not set" && exit 1) \
    && git init -q openarch && cd openarch \
    && git remote add origin "$OPENARCH_GIT_URL" \
    && git fetch -q --depth 1 origin "$OPENARCH_GIT_REF" \
    && git checkout -q -B openarch FETCH_HEAD

RUN --mount=type=cache,target=/root/.m2/repository,id=kg-spaces-openarch-m2 \
    cd openarch \
    && mvn -B -ntp install -DskipTests \
    && cp server/openarch-app/target/openarch-app-*.jar /build/openarch-app.jar

# extracted: OpenArch's runtime finds its bundles through the files on the classpath, not inside a fat jar
RUN java -Djarmode=tools -jar /build/openarch-app.jar extract --destination /build/app

# ----- runtime -----
FROM amazoncorretto:25-alpine

LABEL org.opencontainers.image.title="OpenArch" \
      org.opencontainers.image.source="https://github.com/Hyland/OpenArch"

# the user of Hyland's image
RUN addgroup -g 1000 hyland && adduser -S -u 33010 -G hyland openarch-user \
    && mkdir -p /var/lib/openarch && chown openarch-user:hyland /var/lib/openarch

COPY --from=build /build/app /opt/openarch/app

# the runtime's home, logs and data (binaries): a volume in compose.openarch.yaml
WORKDIR /var/lib/openarch
USER openarch-user
EXPOSE 8080

# settings from the environment (Spring), as with Hyland's image; JAVA_OPTS for extra JVM options
ENTRYPOINT ["/bin/sh", "-c", "exec java $JAVA_OPTS -cp '/opt/openarch/app/openarch-app.jar:/opt/openarch/app/lib/*' com.hyland.openarch.springboot.server.OpenArchApplication"]
