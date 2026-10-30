# renovate: datasource=docker depName=debian versioning=loose
ARG DEBIAN_VERSION=13.7-slim

### Things we need in all build containers
FROM debian:${DEBIAN_VERSION} AS base-build

# Where we'll do all our compiling and similar
ENV BUILD_ROOT=/buildroot
ENV BUILD_TARGET="world-bin"
ENV INSTALL_TARGET="install-world-bin"

# Make the directory for building, and set it as the default for the following Docker commands
COPY ./build-postgres.sh /usr/local/bin
RUN mkdir ${BUILD_ROOT} \
    && chmod +x /usr/local/bin/*
WORKDIR ${BUILD_ROOT}

# Install things needed for development
RUN apt update && \
  apt install -y curl build-essential libicu-dev liblz4-dev locales tzdata zlib1g-dev libzstd-dev pkg-config bison flex && \
  apt clean

FROM base-build AS build-14
## renovate: datasource=repology depName=homebrew/postgresql@14 versioning=loose
ENV PGVERSION="14.24"
RUN /usr/local/bin/build-postgres.sh

FROM base-build AS build-15
## renovate: datasource=repology depName=homebrew/postgresql@15 versioning=loose
ENV PGVERSION=15.19
RUN /usr/local/bin/build-postgres.sh

FROM base-build AS build-16
## renovate: datasource=repology depName=homebrew/postgresql@16 versioning=loose
ENV PGVERSION=16.15
RUN /usr/local/bin/build-postgres.sh

FROM base-build AS build-17
## renovate: datasource=repology depName=homebrew/postgresql@17 versioning=loose
ENV PGVERSION=17.11
RUN /usr/local/bin/build-postgres.sh

FROM base-build AS build-18
## renovate: datasource=repology depName=homebrew/postgresql@18 versioning=loose
ENV PGVERSION=18.6
RUN /usr/local/bin/build-postgres.sh

FROM debian:${DEBIAN_VERSION}

# Copy across our compiled files
COPY --from=build-14 /usr/local-pg14 /usr/local-pg14
COPY --from=build-15 /usr/local-pg15 /usr/local-pg15
COPY --from=build-16 /usr/local-pg16 /usr/local-pg16
COPY --from=build-17 /usr/local-pg17 /usr/local-pg17
COPY --from=build-18 /usr/local-pg18 /usr/local-pg18

# Install locale
RUN apt update && \
  apt install -y icu-devtools locales tzdata \
  && sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
  && locale-gen \
  && locale -a \
  && apt clean

ENV PGTARGET=${PGTARGET}

# Copy across all our shell scripts
WORKDIR /opt
COPY pg_upgrade-entrypoint.sh /usr/local/bin

USER nobody

# Set up the script run by the container when it starts
ENTRYPOINT ["/usr/local/bin/pg_upgrade-entrypoint.sh"]
