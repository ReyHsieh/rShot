#!/bin/bash
#
# build-dmg.sh — rShot DMG 安装包打包脚本
# 用法：./scripts/build-dmg.sh
# 产物：dist/rShot-<版本>.dmg（通用二进制 arm64 + x86_64）
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DIST="$ROOT/dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$ROOT/rShot/Info.plist")"
APP_NAME="rShot"
DMG="$DIST/rShot-${VERSION}.dmg"

echo "==> 1/4 Release 构建（universal: arm64 + x86_64）"
xcodebuild -project rShot.xcodeproj -scheme rShot \
    -configuration Release \
    -destination 'platform=macOS' \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    build >/tmp/rshot_dmg_build.log 2>&1 || {
        tail -30 /tmp/rshot_dmg_build.log; exit 1; }

BUILT_APP="$(xcodebuild -project rShot.xcodeproj -scheme rShot \
    -configuration Release -showBuildSettings 2>/dev/null \
    | awk '/ BUILT_PRODUCTS_DIR =/{print $3}')/$APP_NAME.app"
[ -d "$BUILT_APP" ] || { echo "找不到构建产物: $BUILT_APP"; exit 1; }

echo "==> 2/4 校验架构与签名"
lipo -archs "$BUILT_APP/Contents/MacOS/$APP_NAME"
codesign --verify --deep "$BUILT_APP" && echo "签名校验通过"

echo "==> 3/4 组装 DMG 暂存目录"
STAGING="$DIST/.staging"
rm -rf "$STAGING"; mkdir -p "$STAGING"
cp -R "$BUILT_APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> 4/4 生成 DMG"
mkdir -p "$DIST"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG" >/dev/null
rm -rf "$STAGING"

echo ""
echo "✅ 完成: $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
echo "安装：挂载 DMG → 将 rShot 拖入 Applications"
echo "首次打开（未公证）：右键 App → 打开"
