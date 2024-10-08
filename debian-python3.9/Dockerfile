# The MIT License
#
#  Copyright (c) 2015-2023, CloudBees, Inc. and other Jenkins contributors
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
ARG DEBIAN_RELEASE=bookworm-20240311
ARG JAVA_VERSION=17.0.10_7
FROM eclipse-temurin:"${JAVA_VERSION}"-jdk-jammy AS jre-build

# COPY ../../jenkins-agent /usr/local/bin/jenkins-agent


# This Build ARG is populated by Docker
# Ref. https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
ARG TARGETPLATFORM

SHELL ["/bin/bash","-e", "-u", "-o", "pipefail", "-c"]

# Generate smaller java runtime without unneeded files
# for now we include the full module path to maintain compatibility
# while still saving space (approx 200mb from the full distribution)
RUN if test "${TARGETPLATFORM}" != 'linux/arm/v7'; then \
  case "$(jlink --version 2>&1)" in \
    # jlink version 11 has less features than JDK17+
    "11."*) strip_java_debug_flags=("--strip-debug") ;; \
    *) strip_java_debug_flags=("--strip-java-debug-attributes") ;; \
  esac; \
  jlink \
    --add-modules ALL-MODULE-PATH \
    "${strip_java_debug_flags[@]}" \
    --no-man-pages \
    --no-header-files \
    --compress=2 \
    --output /javaruntime; \
  # It is acceptable to have a larger image in arm/v7 (arm 32 bits) environment.
  # Because jlink fails with the error "jmods: Value too large for defined data type" error.
  else cp -r /opt/java/openjdk /javaruntime; \
  fi

## Agent image target
FROM python:3.9.19-bookworm AS agent

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

RUN groupadd -g "${gid}" "${group}" \
  && useradd -l -c "Jenkins user" -d /home/"${user}" -u "${uid}" -g "${gid}" -m "${user}" || echo "user ${user} already exists."

RUN groupadd -g 2999 docker
RUN /bin/sh -c set -eux; groupadd dockremap; useradd -U -G dockremap dockremap; echo 'dockremap:165536:65536' >> /etc/subuid; echo 'dockremap:165536:65536' >> /etc/subgid # buildkit

ARG AGENT_WORKDIR=/home/"${user}"/agent
ENV TZ=Etc/UTC

## Always use the latest Debian packages: no need for versions
# hadolint ignore=DL3008
RUN apt-get update \
  && apt-get --yes --no-install-recommends install \
    ca-certificates \
    curl \
    fontconfig \
    iproute2 \
    git \
    git-lfs \
    jq \
    less \
    netbase \
    openssh-client \
    iptables \
    e2fsprogs \
    procps \
    unzip \
    xfsprogs \
    openssl \
    patch \
    pigz \
    tzdata \
    xz-utils \
  && apt-get clean \
  && rm -rf /tmp/* /var/cache/* /var/lib/apt/lists/*


ARG VERSION=3206.vb_15dcf73f6a_9
ADD --chown="${user}":"${group}" "https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar" /usr/share/jenkins/agent.jar
RUN chmod 0644 /usr/share/jenkins/agent.jar \
  && ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar

ENV LANG C.UTF-8

ENV JAVA_HOME=/opt/java/openjdk
COPY --from=jre-build /javaruntime "$JAVA_HOME"
ENV PATH="${JAVA_HOME}/bin:${PATH}"


ENV DOCKER_TLS_CERTDIR=/certs
RUN mkdir /certs /certs/client && chmod 1777 /certs /certs/client

COPY --from=docker:dind /usr/local/bin/ /usr/local/bin/
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy
RUN update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# Docker buildx
ARG DOCKER_BUILDX_URL=https://github.com/docker/buildx/releases/download/v0.13.1/buildx-v0.13.1.linux-amd64
RUN wget -O 'docker-buildx' ${DOCKER_BUILDX_URL}
RUN plugin='/usr/local/libexec/docker/cli-plugins/docker-buildx'; mkdir -p "$(dirname "$plugin")"; mv -vT 'docker-buildx' "$plugin"; chmod +x "$plugin"
RUN mkdir -p /home/"${user}"/agent/workspace/pythoncache
RUN mkdir -p /home/"${user}"/agent/workspace/pythontmp
# RUN mkdir -p /home/.aws
ENV PIP_CACHE_DIR="/home/${user}/agent/workspace/pythoncache"
ENV TMPDIR="/home/${user}/agent/workspace/pythontmp"
# ENV AWS_CONFIG_FILE="/home/.aws"

USER "${user}"
ENV AGENT_WORKDIR=${AGENT_WORKDIR}
RUN mkdir -p /home/"${user}"/.jenkins && mkdir -p "${AGENT_WORKDIR}"

VOLUME /var/lib/docker

VOLUME /home/"${user}"/.jenkins
VOLUME "${AGENT_WORKDIR}"
WORKDIR /home/"${user}"
ENV user=${user}
LABEL \
  org.opencontainers.image.vendor="Jenkins project" \
  org.opencontainers.image.title="Official Jenkins Agent Base Docker image" \
  org.opencontainers.image.description="This is a base image, which provides the Jenkins agent executable (agent.jar)" \
  org.opencontainers.image.version="${VERSION}" \
  org.opencontainers.image.url="https://www.jenkins.io/" \
  org.opencontainers.image.source="https://github.com/jenkinsci/docker-agent" \
  org.opencontainers.image.licenses="MIT"

## Inbound Agent image target
FROM agent AS inbound-agent

ARG user=jenkins

USER root
COPY ../../jenkins-agent /usr/local/bin/jenkins-agent
RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave
COPY command.sh /usr/local/bin/command.sh
RUN chmod +x /usr/local/bin/command.sh

ARG G_VERSION=2.1.22
ARG OS=linux  # or "darwin" for OSX, "windows" for Windows.
ARG ARCH=amd64  # or "386" for 32-bit OSs

RUN curl -fsSL "https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v${G_VERSION}/docker-credential-gcr_${OS}_${ARCH}-${G_VERSION}.tar.gz" \
| tar xz docker-credential-gcr \
&& chmod +x docker-credential-gcr && mv docker-credential-gcr /usr/bin/

RUN docker-credential-gcr configure-docker --registries=us-central1-docker.pkg.dev
RUN docker-credential-gcr configure-docker --registries=us-docker.pkg.dev
RUN docker-credential-gcr configure-docker --registries=asia-docker.pkg.dev

# Downloading gcloud package
RUN apt-get --yes --no-install-recommends install apt-transport-https gnupg  && apt-get clean \
  && rm -rf /tmp/* /var/cache/* /var/lib/apt/lists/*
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && apt-get update -y && apt-get install google-cloud-sdk kubectl google-cloud-sdk-gke-gcloud-auth-plugin -y

# AWS
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install
RUN aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
RUN aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
RUN aws configure set region "$AWS_REGION"
# RUN aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 771153997691.dkr.ecr.eu-central-1.amazonaws.com
# RUN aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 771153997691.dkr.ecr.us-east-1.amazonaws.com

# Kubernetes
# RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && \
#       chmod +x ./kubectl && \
#       mv ./kubectl /usr/local/bin/kubectl
    


# USER ${user}

LABEL \
  org.opencontainers.image.vendor="Jenkins project" \
  org.opencontainers.image.title="Official Jenkins Inbound Agent Base Docker image" \
  org.opencontainers.image.description="This is an image for Jenkins agents using TCP or WebSockets to establish inbound connection to the Jenkins controller" \
  org.opencontainers.image.version="${VERSION}" \
  org.opencontainers.image.url="https://www.jenkins.io/" \
  org.opencontainers.image.source="https://github.com/jenkinsci/docker-agent-inbound" \
  org.opencontainers.image.licenses="MIT"



# https://github.com/jenkinsci/docker-agent/tree/master
# ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
# CMD ["/usr/local/bin/jenkins-agent"]
# ENTRYPOINT ["/usr/local/bin/jenkins-agent","/usr/local/bin/dockerd-entrypoint.sh"]
ENTRYPOINT ["/usr/local/bin/command.sh"]
