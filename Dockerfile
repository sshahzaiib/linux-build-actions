# Use an official Ubuntu as a parent image
FROM ubuntu:22.04

# Set environment variables
ENV KERNEL_VERSION=5.15.6
ENV BUSYBOX_VERSION=1.34.1

# Install necessary packages including Linux kernel headers
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    wget \
    bc \
    kmod \
    cpio \
    flex \
    bison \
    libncurses5-dev \
    libelf-dev \
    libssl-dev \
    musl-tools \
    musl-dev \
    linux-headers-$(uname -r)

# Create and switch to the /src directory
WORKDIR /src

# Download and compile Busybox
RUN wget https://www.busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2 && \
    tar -xf busybox-$BUSYBOX_VERSION.tar.bz2 && \
    cd busybox-$BUSYBOX_VERSION && \
    make defconfig && \
    sed 's/^.*CONFIG_STATIC[^_].*$/CONFIG_STATIC=y/g' -i .config && \
    cat .config | grep CONFIG_STATIC && \
    make CC=musl-gcc -j$(nproc) busybox

# Download and extract the Linux kernel
RUN KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d '.' -f 1) && \
    wget https://mirrors.edge.kernel.org/pub/linux/kernel/v$KERNEL_MAJOR.x/linux-$KERNEL_VERSION.tar.xz && \
    tar -xf linux-$KERNEL_VERSION.tar.xz && \
    cd linux-$KERNEL_VERSION && \
    make defconfig && \
    make -j$(nproc) && \
    cd ..

# Copy the compiled kernel image to the root
RUN cp linux-$KERNEL_VERSION/arch/x86_64/boot/bzImage /bzImage

# Prepare the initrd
RUN mkdir initrd && \
    cd initrd && \
    mkdir -p bin dev proc sys && \
    cp ../busybox-$BUSYBOX_VERSION/busybox bin/ && \
    cd bin && \
    for prog in $(./busybox --list); do ln -s /bin/busybox ./$prog; done && \
    cd .. && \
    echo '#!/bin/sh' > init && \
    echo 'mount -t sysfs sysfs /sys' >> init && \
    echo 'mount -t proc proc /proc' >> init && \
    echo 'mount -t devtmpfs udev /dev' >> init && \
    echo 'sysctl -w kernel.printk="2 4 1 7"' >> init && \
    echo '/bin/sh' >> init && \
    echo 'poweroff -f' >> init && \
    chmod -R 777 . && \
    find . | cpio -o -H newc > /initrd.img

# Final working directory
WORKDIR /

# Define entrypoint
ENTRYPOINT ["/bin/bash"]
