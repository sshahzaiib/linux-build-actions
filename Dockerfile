# Stage 1: Base image with Debian Bullseye and necessary tools
FROM debian:bullseye AS base

# Install essential packages
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    wget \
    bc \
    libncurses5-dev \
    flex \
    bison \
    libssl-dev \
    ccache \
    libelf-dev

# Stage 2: Download kernel source
FROM base AS download-kernel

# Set up environment variables
ENV KERNEL_VERSION=5.14
ENV KERNEL_SOURCE=/kernel_source

# Create directory for kernel source
RUN mkdir -p $KERNEL_SOURCE
WORKDIR $KERNEL_SOURCE

# Clone LineageOS kernel source for OnePlus SM8350 (Snapdragon 888) for LineageOS 21 and fetch only the last commit
RUN git clone --depth 1 https://github.com/LineageOS/android_kernel_oneplus_sm8350.git -b lineage-21 .

# Stage 3: Build the kernel
FROM download-kernel AS builder

# Configure and build kernel
RUN cp arch/arm64/configs/defconfig .config && \
    make olddefconfig && \
    make -j$(nproc) && \
    make modules && \
    make modules_install

# Create directory for kernel build artifacts
RUN mkdir -p /kernel_build

# Package kernel into tarball
RUN tar -czvf /kernel.tar.gz -C $KERNEL_SOURCE/arch/arm64/boot/ Image.gz-dtb

# Stage 4: Final image for artifact export
FROM scratch AS export
COPY --from=builder /kernel.tar.gz /kernel.tar.gz
