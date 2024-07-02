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

# Stage 3: Download kernel config (optional if not needed)

# Stage 4: Clone kernel source
FROM install-dependency AS download-kernel
RUN <<"EOF"
cd /
git clone --single-branch --branch blu_spark-14-custom --depth 1 https://github.com/engstk/op9.git kernel_source
EOF

# Stage 5: Build and package the kernel (final stage)
FROM download-kernel as builder
RUN <<"EOF"
cd /kernel_source
cp arch/arm64/configs/blu_spark_defconfig .config
make olddefconfig
make -j`nproc`
make modules
make modules_install
mkdir -p /kernel_build
tar -czvf /kernel.tar.gz -C /kernel_source/arch/arm64/boot/ Image.gz-dtb
EOF
