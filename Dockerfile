# Stage 1: debian base with source list update
FROM debian:12.1 AS deb-src

# Add deb-src to sources.list
COPY <<EOF /etc/apt/sources.list
deb http://deb.debian.org/debian bookworm main
deb-src http://deb.debian.org/debian bookworm main

deb http://deb.debian.org/debian-security/ bookworm-security main
deb-src http://deb.debian.org/debian-security/ bookworm-security main

deb http://deb.debian.org/debian bookworm-updates main
deb-src http://deb.debian.org/debian-security/ bookworm-updates main
EOF

# Stage 2: Install build dependencies
FROM deb-src AS install-dependency

RUN apt-get update && apt-get install -y build-essential wget git apt-get build-dep linux -y

# Stage 3: Download kernel config
FROM install-dependency AS download-boot

RUN mkdir -p debian_config && cd debian_config && \
    wget http://security.debian.org/debian-security/pool/updates/main/l/linux-signed-amd64/linux-image-6.1.0-12-cloud-amd64_6.1.52-1_amd64.deb -q -O kernel.deb && \
    ar -x kernel.deb && tar xf data.tar.xz

# Stage 4: Clone BBR source
FROM download-boot AS download-bbr

RUN git clone https://github.com/google/bbr.git -b v3

# Stage 5: Build and package the kernel (final stage)
FROM download-bbr AS builder

WORKDIR /bbr

COPY debian_config/boot/config-6.1.0-12-cloud-amd64 .config

# Define environment variables
# ENV BRANCH=$(git rev-parse --abbrev-ref HEAD | sed 's/-/+/g')
# ENV SHA1=$(git rev-parse --short HEAD)
ENV LOCALVERSION="+6.1.0-12-cloud-amd64+GCE"
ENV GCE_PKG_DIR=${PWD}/gce/${LOCALVERSION}/pkg
ENV GCE_INSTALL_DIR=${PWD}/gce/${LOCALVERSION}/install
ENV GCE_BUILD_DIR=${PWD}/gce/${LOCALVERSION}/build
ENV KERNEL_PKG=kernel-${LOCALVERSION}.tar.gz2
ENV MAKE_OPTS="-j$(nproc) \
           LOCALVERSION=${LOCALVERSION} \
           EXTRAVERSION="" \
           INSTALL_PATH=${GCE_INSTALL_DIR}/boot \
           INSTALL_MOD_PATH=${GCE_INSTALL_DIR}"

RUN mkdir -p "${GCE_BUILD_DIR}" \
    && mkdir -p "${GCE_INSTALL_DIR}/boot" \
    && mkdir -p "${GCE_PKG_DIR}"

RUN make olddefconfig \
    && make $MAKE_OPTS prepare \
    && make $MAKE_OPTS \
    && make $MAKE_OPTS modules \
    && make $MAKE_OPTS install \
    && make $MAKE_OPTS modules_install

# Copy final kernel archive
CMD ["cd", "${GCE_INSTALL_DIR}"] && ["tar", "-cvzf", "/kernel.tar.gz2", "boot/*", "lib/modules/*"]
