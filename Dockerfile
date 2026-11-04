ARG SONARQUBE_VERSION="community"
# Mantido o escopo global para o primeiro estágio
ARG WORKDIR="/home/build/project"

FROM gradle:8.9-jdk21-jammy AS builder
ARG WORKDIR
COPY . ${WORKDIR}
WORKDIR ${WORKDIR}
RUN gradle build -x test


FROM node:22.16-alpine AS webapp-builder
# Corrigido: Definido o caminho explicitamente para evitar que o Podman perca a variável
WORKDIR /app
COPY ./sonarqube-webapp /app
COPY ./sonarqube-webapp-addons /app/libs/sq-server-addons
RUN yarn install
RUN yarn nx run sq-server:build


FROM sonarqube:${SONARQUBE_VERSION}
ARG PLUGIN_VERSION
ARG WORKDIR

# Copia do primeiro estágio (Usa a variável global que o gradle manteve)
COPY --from=builder --chown=sonarqube:root ${WORKDIR}/build/libs/sonarqube-community-branch-plugin-*.jar /opt/sonarqube/extensions/plugins/

# Copia do estágio do Node (Usa a pasta fixa /app configurada no webapp-builder)
RUN chmod -R 770 /opt/sonarqube/web && rm -rf /opt/sonarqube/web/*
COPY --from=webapp-builder --chown=sonarqube:root /app/apps/sq-server/build/webapp /opt/sonarqube/web
RUN chmod -R 550 /opt/sonarqube/web

ENV PLUGIN_VERSION=${PLUGIN_VERSION}
ENV SONAR_WEB_JAVAADDITIONALOPTS="-javaagent:/opt/sonarqube/extensions/plugins/sonarqube-community-branch-plugin-${PLUGIN_VERSION}.jar=web"
ENV SONAR_CE_JAVAADDITIONALOPTS="-javaagent:/opt/sonarqube/extensions/plugins/sonarqube-community-branch-plugin-${PLUGIN_VERSION}.jar=ce"
