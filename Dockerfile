########################################################################################################################
#
ARG BUILD_ENV=github
ARG SOURCE_REPO=https://github.com/bugficks/docker-gen

########################################################################################################################
#
FROM golang:alpine as builder
LABEL stage=docker-gen-intermediate

ARG BUILD_ENV
ARG SOURCE_REPO

ENV BUILD_ENV=${BUILD_ENV:-github}\
    SOURCE_REPO=${SOURCE_REPO}

RUN apk add --no-cache \
    git \
    make \
    gcc \
    libc-dev \
    curl

########################################################################################################################
#
FROM builder as builder_github
ONBUILD RUN \
    export TAG=${TAG:-$(curl -fsSLI -o /dev/null -w %{url_effective} ${SOURCE_REPO}/releases/latest | awk -F / '{print $NF}')} \
    && git clone ${SOURCE_REPO} --single-branch --branch ${TAG} --depth 1 /build

########################################################################################################################
#
FROM builder as builder_local
ONBUILD COPY . /build

########################################################################################################################
#
FROM builder_${BUILD_ENV} as final

# Tests are disabled here because docker build servers are too slow for ms dependent tests
WORKDIR /build

# Tests are disabled here because docker build servers are too slow for ms dependent tests
RUN make check-gofmt all

########################################################################################################################
#
FROM alpine:latest

LABEL maintainer="github.com/bugficks/docker-gen"

RUN apk --no-cache add openssl

ENV DOCKER_HOST unix:///tmp/docker.sock

COPY --from=final /build/docker-gen /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/docker-gen"]
