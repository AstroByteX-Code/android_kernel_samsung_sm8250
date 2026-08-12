#!/bin/sh
set -e

KERNEL_DIR=$(pwd)
DEVICE="$1"
DEVICE2="$2"
DEVICE3="$3"
TOOLCHAIN_DIR="$4"
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

    cat arch/arm64/configs/vendor/kona-sec-perf_defconfig \
        arch/arm64/configs/vendor/samsung/$DEVICE.config \
        arch/arm64/configs/ksu.config > arch/arm64/configs/temp_defconfig

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

    cat out/arch/arm64/boot/dts/vendor/qcom/kona*.dtb > out/arch/arm64/boot/dts/dtb
}

build_dtbo() {
    echo "-----------------------------------------------"
    echo "Building dtbo.img..."
    echo "-----------------------------------------------"
    DTBO_FILES=$(find out/arch/arm64/boot/dts/samsung/$DEVICE -name "kona-sec-$DEVICE-*.dtbo")
    tools/mkdtimg create out/dtbo.img --page_size=4096 ${DTBO_FILES}
}

prepare_ak3() {
    cd AnyKernel3/
    mv "$KERNEL_DIR/out/dtbo.img" dtbo.img
    mv "$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb" Image.gz-dtb
    mv "$KERNEL_DIR/out/arch/arm64/boot/dts/dtb" dtb

    sed -i "s/^device\.name1=.*/device.name1=${DEVICE}/" anykernel.sh
    sed -i "s/^device\.name2=.*/device.name2=${DEVICE2}/" anykernel.sh
    sed -i "s/^device\.name3=.*/device.name3=${DEVICE3}/" anykernel.sh

    cd "$KERNEL_DIR"
}

package_zip() {
    echo "-----------------------------------------------"
    echo "Packaging AnyKernel3 zip..."
    echo "-----------------------------------------------"
    cd AnyKernel3/
    zip -r9 "Astro-Kernel-${DEVICE}-${TOOLCHAIN_NAME}-${BUILD_DATE}.zip" * -x "*.git*" -x "README.md"
    cd "$KERNEL_DIR"
}

build_kernel
build_dtb
build_dtbo
prepare_ak3
package_zip
