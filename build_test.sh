#!/bin/sh
set -e

KERNEL_DIR=$(pwd)
DEVICE="$1"
TOOLCHAIN_DIR="$2"
TOOLCHAIN_NAME="${TOOLCHAIN_NAME:-$(basename "$TOOLCHAIN_DIR")}"
export PATH="$TOOLCHAIN_DIR/bin:$PATH"

BUILD_DATE=$(date +%Y%m%d)

build_kernel() {
    echo "-----------------------------------------------"
    echo "Beginning kernel compilation for $DEVICE..."
    echo "Using toolchain: $TOOLCHAIN_NAME"
    echo "-----------------------------------------------"

    export ARCH=arm64
    mkdir -p out

    BUILD_VAR="-j$(nproc) -C $(pwd) O=$(pwd)/out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1"

    # Merge defconfigs
    cat arch/arm64/configs/vendor/kona-sec-perf_defconfig \
        arch/arm64/configs/vendor/samsung/$DEVICE.config \
        arch/arm64/configs/ksu.config > arch/arm64/configs/temp_defconfig

    # Append local version string
    echo "CONFIG_LOCALVERSION=\"-AstroForge-${BUILD_DATE}\"" >> arch/arm64/configs/temp_defconfig
    echo 'CONFIG_LTO_CLANG=y' >> arch/arm64/configs/temp_defconfig
    echo 'CONFIG_THINLTO=y' >> arch/arm64/configs/temp_defconfig
    echo '# CONFIG_LTO_CLANG_FULL is not set' >> arch/arm64/configs/temp_defconfig

    make $BUILD_VAR temp_defconfig
    rm arch/arm64/configs/temp_defconfig
}

build_dtb() {
    echo "-----------------------------------------------"
    echo "Building dtb..."
    echo "-----------------------------------------------"
    make $BUILD_VAR
    make $BUILD_VAR dtbs

    cat "$(pwd)/out/arch/arm64/boot/dts/vendor/qcom/kona.dtb" \
        "$(pwd)/out/arch/arm64/boot/dts/vendor/qcom/kona-v2.dtb" \
        "$(pwd)/out/arch/arm64/boot/dts/vendor/qcom/kona-v2.1.dtb" \
        > "$(pwd)/out/arch/arm64/boot/dts/dtb"
}

build_dtbo() {
    echo "-----------------------------------------------"
    echo "Building dtbo.img..."
    echo "-----------------------------------------------"
    DTBO_FILES=$(find $(pwd)/out/arch/arm64/boot/dts/samsung/$DEVICE -name kona-sec-$DEVICE-*.dtbo)
    $(pwd)/tools/mkdtimg create $(pwd)/out/dtbo.img --page_size=4096 ${DTBO_FILES}
}

prepare_ak3() {
    cd AnyKernel3/

    mv "$KERNEL_DIR/out/dtbo.img" dtbo.img
    mv "$KERNEL_DIR/out/arch/arm64/boot/Image" Image

    mv "$KERNEL_DIR/out/arch/arm64/boot/dts/dtb" dtb

    sed -i "s/^device\.name1=.*/device.name1=${DEVICE}/" anykernel.sh

    ZIP_NAME="Astro-Kernel-${DEVICE}-${TOOLCHAIN_NAME}-${BUILD_DATE}.zip"
    zip -r "../${ZIP_NAME}" *

    cd "$KERNEL_DIR"
}

build_kernel
build_dtb
build_dtbo
prepare_ak3
