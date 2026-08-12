#!/bin/sh

KERNEL_DIR=$(pwd)
DEVICE="$1"

# Capture build start time/date
BUILD_DATE=$(date +"%Y-%m-%d_%H-%M")
BUILD_HUMAN=$(date +"%A, %d %B %Y %H:%M")

build_kernel() {
    echo "-----------------------------------------------"
    echo "Beginning kernel compilation for $DEVICE..."
    echo "Build started at: $BUILD_HUMAN"
    echo "-----------------------------------------------"

    export ARCH=arm64
    mkdir -p out

    # Add LLVM toolchain to PATH
    export PATH="$KERNEL_DIR/llvm-21/bin:$PATH"

    # Common build variables
    BUILD_VAR="-j$(nproc) -C $KERNEL_DIR O=$KERNEL_DIR/out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1"

    # Merge defconfigs into a temporary one
    cat arch/arm64/configs/vendor/kona-sec-perf_defconfig \
        arch/arm64/configs/vendor/samsung/${DEVICE}.config \
        arch/arm64/configs/ksu.config > arch/arm64/configs/temp_defconfig

    # Append local version string
    echo "CONFIG_LOCALVERSION=\"-AstroForge-${BUILD_DATE}\"" >> arch/arm64/configs/temp_defconfig

    # Force ThinLTO only (disable full LTO)
    echo 'CONFIG_LTO_CLANG=y' >> arch/arm64/configs/temp_defconfig
    echo 'CONFIG_THINLTO=y' >> arch/arm64/configs/temp_defconfig
    echo '# CONFIG_LTO_CLANG_FULL is not set' >> arch/arm64/configs/temp_defconfig

    # Build defconfig
    make $BUILD_VAR temp_defconfig
    rm arch/arm64/configs/temp_defconfig
}

build_dtb() {
    echo "-----------------------------------------------"
    echo "Building dtb..."
    echo "-----------------------------------------------"
    make $BUILD_VAR
    make $BUILD_VAR dtbs

    cat "$KERNEL_DIR/out/arch/arm64/boot/dts/vendor/qcom/kona.dtb" \
        "$KERNEL_DIR/out/arch/arm64/boot/dts/vendor/qcom/kona-v2.dtb" \
        "$KERNEL_DIR/out/arch/arm64/boot/dts/vendor/qcom/kona-v2.1.dtb" \
        > "$KERNEL_DIR/out/arch/arm64/boot/dts/dtb"
}

build_dtbo() {
    echo "-----------------------------------------------"
    echo "Building dtbo.img..."
    echo "-----------------------------------------------"
    DTBO_FILES=$(find "$KERNEL_DIR/out/arch/arm64/boot/dts/samsung/$DEVICE" -name "kona-sec-$DEVICE-*.dtbo")
    "$KERNEL_DIR/tools/mkdtimg" create "$KERNEL_DIR/out/dtbo.img" --page_size=4096 ${DTBO_FILES}
}

prepare_ak3() {
    echo "-----------------------------------------------"
    echo "Packaging AnyKernel3 zip..."
    echo "-----------------------------------------------"
    cd AnyKernel3/ || exit 1

    mv "$KERNEL_DIR/out/dtbo.img" dtbo.img
    mv "$KERNEL_DIR/out/arch/arm64/boot/Image" Image
    mv "$KERNEL_DIR/out/arch/arm64/boot/dts/dtb" dtb

    sed -i "s/^device\.name1=.*/device.name1=${DEVICE}/" anykernel.sh

    ZIP_NAME="Astro-Kernel-${DEVICE}-${BUILD_DATE}.zip"
    zip -r "../${ZIP_NAME}" *

    cd "$KERNEL_DIR"
    echo "✅ Build completed at: $(date +"%A, %d %B %Y %H:%M")"
    echo "Output zip: $ZIP_NAME"
}

# Run build stages
build_kernel
build_dtb
build_dtbo
prepare_ak3
