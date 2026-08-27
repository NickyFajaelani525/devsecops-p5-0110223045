# Stage 1: Docker CLI
FROM docker:cli AS docker-cli

# Stage 2: Jenkins
FROM jenkins/jenkins:lts

USER root

RUN groupadd -g 960 docker \
    && usermod -aG docker jenkins

# Copy Docker CLI dari stage sebelumnya
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker

USER jenkins
