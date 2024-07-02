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
    ccache

# Stage 2: Download kernel source
FROM base AS download-kernel

# Set up environment variables
ENV KERNEL_VERSION=5.14  # Replace with your kernel version
ENV KERNEL_SOURCE=/kernel_source

# Create directory for kernel source
RUN mkdir -p $KERNEL_SOURCE
WORKDIR $KERNEL_SOURCE

# Clone kernel source (replace with your repository)
RUN git clone https://github.com/engstk/op9.git -b blu_spark-14-custom .

# Stage 3: Build the kernel
FROM download-kernel AS builder

# Configure and build kernel
RUN cp arch/arm64/configs/blu_spark_defconfig .config && \
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
