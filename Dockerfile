# syntax=docker/dockerfile:1.7

ARG MAVEN_IMAGE=maven:3.6.3-openjdk-8
ARG JAVA_IMAGE=eclipse-temurin:8-jre-jammy

FROM ${MAVEN_IMAGE} AS build

ARG APP_MODULE=gateway
WORKDIR /workspace
COPY deploy/docker/maven-settings.xml /opt/maven-settings.xml
COPY . .

RUN --mount=type=cache,id=wukong-crm-maven-v2,target=/root/.m2 \
    set -eux; \
    mvn -s /opt/maven-settings.xml -B -DskipTests -pl "${APP_MODULE}" -am package; \
    artifact="$(find "${APP_MODULE}/target" -maxdepth 1 -type f -name '*.jar' | head -n 1)"; \
    test -n "${artifact}"; \
    mkdir -p /out; \
    cp "${artifact}" /out/app.jar; \
    cp -R "${APP_MODULE}/target/lib" /out/lib; \
    cp -R "${APP_MODULE}/target/config" /out/config; \
    if [ -d "${APP_MODULE}/target/public" ]; then cp -R "${APP_MODULE}/target/public" /out/public; fi

FROM ${JAVA_IMAGE}

WORKDIR /app
COPY --from=build --chown=10001:0 /out/ /app/

ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_OPTS="-Xms256m -Xmx512m -Djava.security.egd=file:/dev/./urandom" \
    APP_ARGS=""

RUN mkdir -p /opt/upload/private /opt/upload/public /tmp/wkcrm && \
    chown -R 10001:0 /app /opt/upload /tmp/wkcrm

USER 10001
EXPOSE 8443

ENTRYPOINT ["sh", "-c", "exec java ${JAVA_OPTS} -jar /app/app.jar ${APP_ARGS}"]
