# Stage 1: debian base with source list update
FROM debian:12.1 AS deb-src
COPY <<"EOF" /etc/apt/sources.list
deb http://deb.debian.org/debian bookworm main
deb-src http://deb.debian.org/debian bookworm main

deb http://deb.debian.org/debian-security/ bookworm-security main
deb-src http://deb.debian.org/debian-security/ bookworm-security main

deb http://deb.debian.org/debian bookworm-updates main
deb-src http://deb.debian.org/debian bookworm-updates main
EOF


# Stage 2: Install build dependencies
FROM deb-src AS install-dependency
RUN <<"EOF"
apt-get update
apt-get install build-essential wget git -y
apt-get build-dep linux -y
EOF

# Stage 3: Download kernel config
FROM install-dependency AS download-boot
RUN <<"EOF"
cd /
mkdir debian_config
cd debian_config
wget http://security.debian.org/debian-security/pool/updates/main/l/linux-signed-amd64/linux-image-6.1.0-12-cloud-amd64_6.1.52-1_amd64.deb -q -O kernel.deb
ar -x kernel.deb
tar xf data.tar.xz
EOF

# Stage 4: Clone BBR source
FROM download-boot as download-bbr
RUN <<"EOF"
cd /
git clone https://github.com/google/bbr.git -b v3
EOF

# Stage 5: Build and package the kernel (final stage)
FROM download-bbr as builder
RUN <<"EOF"
cd /bbr
cp /debian_config/boot/config-6.1.0-12-cloud-amd64 .config
export BRANCH=`git rev-parse --abbrev-ref HEAD | sed s/-/+/g`
export SHA1=`git rev-parse --short HEAD`
export LOCALVERSION=+${BRANCH}+${SHA1}+GCE
export GCE_PKG_DIR=${PWD}/gce/${LOCALVERSION}/pkg
export GCE_INSTALL_DIR=${PWD}/gce/${LOCALVERSION}/install
export GCE_BUILD_DIR=${PWD}/gce/${LOCALVERSION}/build
export KERNEL_PKG=kernel-${LOCALVERSION}.tar.gz2
export MAKE_OPTS="-j`nproc` \
           LOCALVERSION=${LOCALVERSION} \
           EXTRAVERSION="" \
           INSTALL_PATH=${GCE_INSTALL_DIR}/boot \
           INSTALL_MOD_PATH=${GCE_INSTALL_DIR}"
mkdir -p ${GCE_BUILD_DIR}
mkdir -p ${GCE_INSTALL_DIR}/boot
mkdir -p ${GCE_PKG_DIR}
make olddefconfig
make ${MAKE_OPTS} prepare
make ${MAKE_OPTS}
make ${MAKE_OPTS} modules
make ${MAKE_OPTS} install
make ${MAKE_OPTS} modules_install
cd ${GCE_INSTALL_DIR}
tar -cvzf /kernel.tar.gz2 boot/* lib/modules/* --owner=0 --group=0
EOF
