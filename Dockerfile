ARG POSTGRES_TAG=18-alpine

FROM postgres:${POSTGRES_TAG} AS extension-builder

ENV PATH=/root/.cargo/bin:$PATH

SHELL ["/bin/ash", "-e", "-o", "pipefail", "-c"]

RUN apk add --no-cache --virtual .extension-build-deps \
    ${DOCKER_PG_LLVM_DEPS} \
    bison \
    build-base \
    ca-certificates \
    cargo \
    clang21-libclang \
    flex \
    git \
    jq \
    openssl-dev \
    pax-utils \
    perl \
    pkgconf \
    rust \
    rustfmt

RUN set -eux; \
    llvm_config="$(find /usr/lib -path '*/bin/llvm-config' -print -quit)"; \
    clang="$(find /usr/bin -maxdepth 1 -name 'clang-[0-9]*' -print -quit)"; \
    libclang="$(find /usr/lib -name 'libclang.so*' -print -quit)"; \
    command -v rustfmt; \
    test -n "${llvm_config}"; \
    test -n "${clang}"; \
    test -n "${libclang}"; \
    ln -sf "${llvm_config}" /usr/local/bin/llvm-config; \
    ln -sf "${clang}" /usr/local/bin/clang; \
    ln -sf "${libclang}" /usr/local/lib/libclang.so

ENV LLVM_CONFIG=/usr/local/bin/llvm-config
ENV CLANG=/usr/local/bin/clang
ENV LIBCLANG_PATH=/usr/local/lib

ARG PGVECTOR_VERSION=0.8.2
RUN set -eux; \
    git clone --depth 1 --branch "v${PGVECTOR_VERSION}" https://github.com/pgvector/pgvector.git /tmp/pgvector; \
    make -C /tmp/pgvector PG_CONFIG="$(command -v pg_config)" OPTFLAGS=""; \
    make -C /tmp/pgvector PG_CONFIG="$(command -v pg_config)" install; \
    rm -rf /tmp/pgvector

ARG PGVECTORSCALE_VERSION=0.9.0
RUN set -eux; \
    git clone --depth 1 --branch "${PGVECTORSCALE_VERSION}" https://github.com/timescale/pgvectorscale.git /tmp/pgvectorscale; \
    cd /tmp/pgvectorscale/pgvectorscale; \
    cargo install --locked cargo-pgrx --version "$(cargo metadata --format-version 1 | jq -r '.packages[] | select(.name == "pgrx") | .version')"; \
    cargo pgrx init --pg18 "$(command -v pg_config)"; \
    cargo pgrx install --release; \
    rm -rf /tmp/pgvectorscale /root/.cargo /root/.rustup

ARG APACHE_AGE_VERSION=release/PG18/1.7.0
RUN set -eux; \
    git clone --depth 1 --branch "${APACHE_AGE_VERSION}" https://github.com/apache/age.git /tmp/age; \
    make -C /tmp/age PG_CONFIG="$(command -v pg_config)"; \
    make -C /tmp/age PG_CONFIG="$(command -v pg_config)" install; \
    rm -rf /tmp/age

RUN set -eux; \
    strip --strip-unneeded \
    /usr/local/lib/postgresql/vector.so \
    /usr/local/lib/postgresql/vectorscale*.so \
    /usr/local/lib/postgresql/age.so; \
    scanelf --needed --nobanner --format '%n' \
    /usr/local/lib/postgresql/vector.so \
    /usr/local/lib/postgresql/vectorscale*.so \
    /usr/local/lib/postgresql/age.so \
    | tr ',' '\n' \
    | awk 'NF' \
    | sort -u \
    | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    > /extension-rundeps.txt

FROM postgres:${POSTGRES_TAG}

COPY --from=extension-builder /extension-rundeps.txt /tmp/extension-rundeps.txt
RUN set -eux; \
    if [ -s /tmp/extension-rundeps.txt ]; then \
    apk add --no-cache --virtual .extension-rundeps $(cat /tmp/extension-rundeps.txt); \
    fi; \
    rm /tmp/extension-rundeps.txt

COPY --from=extension-builder /usr/local/lib/postgresql/vector.so /usr/local/lib/postgresql/
COPY --from=extension-builder /usr/local/share/postgresql/extension/vector.control /usr/local/share/postgresql/extension/
COPY --from=extension-builder /usr/local/share/postgresql/extension/vector--*.sql /usr/local/share/postgresql/extension/

COPY --from=extension-builder /usr/local/lib/postgresql/vectorscale*.so /usr/local/lib/postgresql/
COPY --from=extension-builder /usr/local/share/postgresql/extension/vectorscale.control /usr/local/share/postgresql/extension/
COPY --from=extension-builder /usr/local/share/postgresql/extension/vectorscale--*.sql /usr/local/share/postgresql/extension/

COPY --from=extension-builder /usr/local/lib/postgresql/age.so /usr/local/lib/postgresql/
COPY --from=extension-builder /usr/local/share/postgresql/extension/age.control /usr/local/share/postgresql/extension/
COPY --from=extension-builder /usr/local/share/postgresql/extension/age--*.sql /usr/local/share/postgresql/extension/
