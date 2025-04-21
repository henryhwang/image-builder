ARG BUILD_IMAGE=rust:1.81-slim
ARG BUILD_DEPS
ARG TARGET
ARG GITHUB_REPO
ARG RUNTIME_IMAGE

FROM ${BUILD_IMAGE} AS builder

WORKDIR /usr/src/app
ARG BUILD_DEPS
ARG GITHUB_REPO
ARG BUILD_COMMAND
ARG TARGET

RUN if [ -n "${BUILD_DEPS}" ]; then \
    apk add --no-cache ${BUILD_DEPS}; \
    fi

RUN apk add --no-cache git \
    && git clone https://github.com/${GITHUB_REPO}.git . \
    && apk del git

RUN if [ -n "${TARGET}" ]; then \
    rustup target add ${TARGET} && \
    eval ${BUILD_COMMAND} --target ${TARGET}; \
    else \
    eval ${BUILD_COMMAND}; \
    fi

FROM ${RUNTIME_IMAGE}

WORKDIR /app
ARG TARGET_BINARY
ARG BINARY_NAME

COPY --from=builder /usr/src/app/${TARGET_BINARY} /app/${BINARY_NAME}

RUN chmod +x /app/${BINARY_NAME}

ENV PATH="/app:${PATH}"

ENTRYPOINT ["/app/${BINARY_NAME}"]
CMD ["--help"]
