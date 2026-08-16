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

echo "==> 3/5 组装 DMG 暂存目录（/tmp：避开 iCloud File Provider 异步写回 hidden/FinderInfo 属性）"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/rshot-dmg.XXXXXX")"
cp -R "$BUILT_APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
# 保险：清除一切扩展属性与 flags（FinderInfo 的 invisible 位会让 Finder 隐藏 app → 安装窗口空白）
xattr -cr "$STAGING/$APP_NAME.app" 2>/dev/null || true
chflags -R nouchg,noschg,nohidden "$STAGING/$APP_NAME.app" 2>/dev/null || true

echo "==> 4/5 设置挂载时自动打开窗口（bless，系统原生标记）"
# RW 镜像放 staging 外：hdiutil create -srcfolder 的输出目标不能在源目录内（自包含失败）
RW_DMG="${STAGING}-rw.dmg"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDRW \
    "$RW_DMG" >/dev/null 2>&1
hdiutil attach "$RW_DMG" -nobrowse -quiet
MOUNT="/Volumes/$APP_NAME"
# bless 写入卷的自动打开标记（Finder 默认视图完整显示全部项目）。
# 不用 AppleScript 写 .DS_Store 布局：实测会产生损坏数据（丢图标/无效 bounds → 窗口空白）。
bless --openfolder "$MOUNT" 2>/dev/null || true
sleep 1
# 卸载（Finder 可能仍握着卷，重试直至成功）
for i in 1 2 3 4 5; do
    if hdiutil detach "$MOUNT" -quiet 2>/dev/null; then break; fi
    if [ "$i" = 5 ]; then
        hdiutil detach "$MOUNT" -force || true
    fi
    sleep 2
done

echo "==> 5/5 压缩为 UDZO"
mkdir -p "$DIST"
rm -f "$DMG"
for i in 1 2 3; do
    if hdiutil convert "$RW_DMG" -format UDZO -o "$DMG" >/dev/null 2>&1; then
        rm -rf "$STAGING"
        echo ""
        echo "✅ 完成: $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
        echo "安装：双击 DMG 自动弹窗 → 将 rShot 拖入 Applications"
        echo "首次打开（未公证）：右键 App → 打开"
        exit 0
    fi
    sleep 2
done
echo "❌ UDZO 压缩失败"; exit 1
