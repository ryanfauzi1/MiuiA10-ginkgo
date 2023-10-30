#!/usr/bin/env bash
#
# Copyright (C) 2020 Edwiin Kusuma Jaya (MWG_Ryzen)
#
# Simple Local Kernel Build Script
#
# Configured for Redmi Note 8 / ginkgo custom kernel source
#
# Setup build env with akhilnarang/scripts repo
#
# Use this script on root of kernel directory

# setup telegram env
API_BOT="6787166379:AAGXuTzT49V0DdAzLiRB4Lj3PUsVQWkIiJM"
CHATID="-4064889762"
export CHATID API_BOT TYPE_KERNEL
export WAKTU=$(date +"%T")
export TGL=$(date +"%d-%m-%Y")
export BOT_MSG_URL="https://api.telegram.org/bot$API_BOT/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$API_BOT/sendDocument"

tg_sticker() {
   curl -s -X POST "https://api.telegram.org/bot$API_BOT/sendSticker" \
        -d sticker="$1" \
        -d chat_id=$CHATID
}

tg_post_msg() {
        curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
        -d "parse_mode=markdown" \
        -d text="$1"
}

tg_post_build() {
        #Post MD5Checksum alongwith for easeness
        MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

        #Show the Checksum alongwith caption
        curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$2" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=markdown" \
        -F caption="$3 MD5 \`$MD5CHECK\`"
}

tg_error() {
        curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$2" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$3Failed to build , check <code>error.log</code>"
}

bold=$(tput bold)
normal=$(tput sgr0)

# Scrip option
while (( ${#} )); do
    case ${1} in
        "-Z"|"--zip") ZIP=true ;;
    esac
    shift
done


[[ -z ${ZIP} ]] && { echo "${bold}Gunakan -Z atau --zip Untuk Membuat Zip Kernel Installer${normal}"; }

# Clone toolchain
#if ! [ -d "../toolchain" ]; then
#    wget -O proton.tar.zst https://github.com/kdrag0n/proton-clang/archive/20200801.tar.gz
#    mkdir -p ../toolchain/clang
#    sudo tar -I zstd -xvf proton.tar.zst -C ../toolchain/clang --strip-components=1
#else
#    echo "${bold}Folder Toolchain Sudah Tersedia, Tidak Perlu Di Clone${normal}"
#fi

if ! [ -d "$HOME/cosmic" ]; then
echo "Cosmic clang not found! Cloning..."
if ! git clone -q https://github.com/kdrag0n/proton-clang.git --depth=1 -b master ~/cosmic; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

# ENV
CONFIG=vendor/ginkgo-perf_defconfig
KERNEL_DIR=$(pwd)
PARENT_DIR="$(dirname "$KERNEL_DIR")"
KERN_IMG="$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb"
export KBUILD_BUILD_USER="root"
export KBUILD_BUILD_HOST="xderm"
export PATH="$HOME/cosmic/bin:$PATH"
export KBUILD_COMPILER_STRING="$($HOME/cosmic/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

# Functions
clang_build () {
    make -j O=out \
                          ARCH=arm64 \
                          CC="clang" \
                          AR="llvm-ar" \
                          NM="llvm-nm" \
                          CLANG_TRIPLE=aarch64-linux-gnu- \
                          CROSS_COMPILE=aarch64-linux-gnu- \
                          CROSS_COMPILE_ARM32=arm-linux-gnueabi- 
}

# Build kernel
make O=out ARCH=arm64 $CONFIG > /dev/null
echo -e "${bold}Compiling with CLANG${normal}\n$KBUILD_COMPILER_STRING"
clang_build

if ! [ -a "$KERN_IMG" ]; then
    echo "${bold}Build error, Tolong Perbaiki Masalah Ini${normal}"
    exit 1
fi

[[ -z ${ZIP} ]] && { exit; }

# clone AnyKernel3
if ! [ -d "AnyKernel3" ]; then
    git clone https://github.com/kutemeikito/AnyKernel3
else
    echo "${bold}Direktori AnyKernel3 Sudah Ada, Tidak Perlu di Clone${normal}"
fi

# ENV
ZIP_DIR=$KERNEL_DIR/AnyKernel3
VENDOR_MODULEDIR="$ZIP_DIR/modules/vendor/lib/modules"
STRIP="aarch64-linux-gnu-strip"

# Make zip
make -C "$ZIP_DIR" clean
wifi_modules
cp "$KERN_IMG" "$ZIP_DIR"/
make -C "$ZIP_DIR" normal

# stiker post
echo "Uploading your kernel.."
DEVICE="Redmi Note 8"
MESIN="Git Workflows"
DATE=$(date +"%Y%m%d-%H%M%S")
KOMIT=$(git log --pretty=format:'"%h : %s"' -2)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
TYPE="MIUI"

TEXT1="
*Build Completed Successfully*
━━━━━━━━━ஜ۩۞۩ஜ━━━━━━━━
* Device* : \`$DEVICE\`
* Code name* : \`Ginkgo\`
* Variant Build* : \`$TYPE\`
* Branch Build* : \`$BRANCH\`
* System Build* : \`$MESIN\`
* Date Build* : \`$TGL\` \`$WAKTU\`
* Last Commit* : \`$KOMIT\`
* Author* : @fchelz
━━━━━━━━━ஜ۩۞۩ஜ━━━━━━━━"

                tg_post_msg "$TEXT1" "$CHATID"
                tg_post_build "$ZIP_DIR" "$CHATID"
exit

