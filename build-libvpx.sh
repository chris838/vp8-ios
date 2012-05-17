#!/bin/bash

ROOT_DIR="`pwd`"
SRC_DIR="`pwd`/libvpx"
BUILD_DIR="`pwd`/build"
LIB_DIR="`pwd`/lib"
INCLUDE_DIR="`pwd`/include"

# Compile for each of the three architecures (i386 for simulator)
cd $ROOT_DIR
mkdir -p $BUILD_DIR/armv6
cd $BUILD_DIR/armv6 
$SRC_DIR/configure --target=armv6-darwin-gcc --sdk-path=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer --libc=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk/
make 

cd $ROOT_DIR
mkdir -p $BUILD_DIR/armv7
cd $BUILD_DIR/armv7
$SRC_DIR/configure --target=armv7-darwin-gcc  --sdk-path=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer --libc=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk/
make 

cd $ROOT_DIR
mkdir -p $BUILD_DIR/i386 
cd $BUILD_DIR/i386
$SRC_DIR/configure --target=x86-darwin9-gcc  --sdk-path=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer --libc=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk/
make

# Combine into universal binary
mkdir -p $LIB_DIR
lipo $BUILD_DIR/armv6/libvpx.a -arch armv7 $BUILD_DIR/armv7/libvpx.a -arch i386 $BUILD_DIR/i386/libvpx.a -create -output $LIB_DIR/libvpx.a

# Copy headers
mkdir -p $INCLUDE_DIR
cd $SRC_DIR
cp vpx/*.h $INCLUDE_DIR
#for f in $BUILD_DIR/*.h; do sed -i '' 's/\#include "vpx\//\#include "/' $f; done 