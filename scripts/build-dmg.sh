#!/bin/bash
#
# build-dmg.sh — rShot DMG 安装包打包脚本
# 用法：./scripts/build-dmg.sh
# 产物：dist/rShot-<版本>.dmg（通用二进制 arm64 + x86_64）
#
# 流程：Release 构建 → 组装暂存 → 可写 DMG → Finder 窗口布局
#      （自动打开 + 大图标 + app左/Applications右）→ 压缩为 UDZO
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DIST="$ROOT/dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$ROOT/rShot/Info.plist")"
APP_NAME="rShot"
DMG="$DIST/rShot-${VERSION}.dmg"

echo "==> 1/5 Release 构建（universal: arm64 + x86_64）"
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

echo "==> 2/5 校验架构与签名"
lipo -archs "$BUILT_APP/Contents/MacOS/$APP_NAME"
codesign --verify --deep "$BUILT_APP" && echo "签名校验通过"

echo "==> 3/5 组装 DMG 暂存目录"
STAGING="$DIST/.staging"
rm -rf "$STAGING"; mkdir -p "$STAGING"
cp -R "$BUILT_APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> 4/5 设置 Finder 窗口布局（自动打开 + 图标位置）"
RW_DMG="$DIST/.rShot-rw.dmg"
rm -f "$RW_DMG"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDRW \
    "$RW_DMG" >/dev/null 2>&1
hdiutil attach "$RW_DMG" -nobrowse -quiet
MOUNT="/Volumes/$APP_NAME"
# 大图标视图：app 左中、Applications 右中
osascript <<APPLESCRIPT || true
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set the bounds of container window to {200, 120, 760, 440}
        set icon size of the icon view options of the container window to 96
        set position of item "$APP_NAME" of container window to {140, 160}
        set position of item "Applications" of container window to {420, 160}
    end tell
end tell
APPLESCRIPT
# 同步 .DS_Store 落盘
sleep 1
osascript -e "tell application \"Finder\" to update disk \"$APP_NAME\"" >/dev/null 2>&1 || true
sleep 1
# 卸载（Finder 可能仍握着卷，重试直至成功）
for i in 1 2 3 4 5; do
    if hdiutil detach "$MOUNT" -quiet 2>/dev/null; then break; fi
    [ "$i" = 5 ] && { hdiutil detach "$MOUNT" -force; }
    sleep 2
done

echo "==> 5/5 压缩为 UDZO"
mkdir -p "$DIST"
rm -f "$DMG"
for i in 1 2 3; do
    if hdiutil convert "$RW_DMG" -format UDZO -o "$DMG" >/dev/null 2>&1; then
        rm -f "$RW_DMG"; rm -rf "$STAGING"
        echo ""
        echo "✅ 完成: $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
        echo "安装：双击 DMG 自动弹窗 → 将 rShot 拖入 Applications"
        echo "首次打开（未公证）：右键 App → 打开"
        exit 0
    fi
    sleep 2
done
echo "❌ UDZO 压缩失败"; exit 1
