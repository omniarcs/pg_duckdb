ARG PG_MAJOR=16
ARG DUCKDB_VERSION=v1.1.0
FROM postgres:$PG_MAJOR AS pg_duckdb
ARG PG_MAJOR
ARG DUCKDB_VERSION

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    bison \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    flex \
    g++ \
    gfortran \
    git \
    libc++-dev \
    libc++abi-dev \
    libglib2.0-dev \
    liblz4-dev \
    libreadline-dev \
    libssl-dev \
    libstdc++-12-dev \
    libtinfo5 \
    libxml2-dev \
    libxml2-utils \
    libxslt-dev \
    make \
    musl-dev \
    ninja-build \
    openssh-client \
    pkg-config \
    postgresql-server-dev-$PG_MAJOR \
    xsltproc \
    zlib1g-dev && \
    mkdir -p -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts

COPY . /pg_duckdb/
WORKDIR /pg_duckdb
RUN --mount=type=ssh git submodule update --init --recursive --recommend-shallow && \
    cd third_party/duckdb && \
    git checkout $DUCKDB_VERSION

RUN --mount=type=ssh --mount=target=/pg_duckdb/third_party/duckdb/build,type=cache \
    # rm -rf /pg_duckdb/third_party/duckdb/build/* && \
    # curl -L https://github.com/duckdb/pg_duckdb/pull/103.patch -o pr.patch && \
    curl -L https://github.com/omniarcs/pg_duckdb/commit/00b0772e0c6d96d16377576488e38aa0e2b2a299.patch -o pr.patch && \
    git apply pr.patch && \
    OVERRIDE_GIT_DESCRIBE=$DUCKDB_VERSION GEN=ninja make

FROM postgres:$PG_MAJOR AS postgres
ARG PG_MAJOR

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    make \
    ca-certificates

# RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
#     --mount=target=/var/cache/apt,type=cache,sharing=locked \
#     apt-get -f -y --no-install-recommends install curl apt-transport-https lsb-release gnupg python3-pip && \
#     curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.asc.gpg && \
#     CLI_REPO=$(lsb_release -cs) && \
#     echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ ${CLI_REPO} main" \
#     > /etc/apt/sources.list.d/azure-cli.list && \
#     apt-get update && \
#     apt-get install -y azure-cli && \
#     rm -rf /var/lib/apt/lists/*

COPY ./Makefile.install /tmp/Makefile
RUN --mount=type=bind,from=pg_duckdb,source=/pg_duckdb,target=/pg_duckdb,rw \
    --mount=type=bind,from=pg_duckdb,source=/usr/lib/llvm-16,target=/usr/lib/llvm-16 \
    --mount=target=/pg_duckdb/third_party/duckdb/build,type=cache \
    cd /pg_duckdb && cp /tmp/Makefile . && make install
