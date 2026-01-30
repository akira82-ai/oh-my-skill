#!/bin/bash

# Oh My Skill - 构建脚本

set -e

APP_NAME="OhMySkill"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "🔨 构建 $APP_NAME..."

# 解析依赖
echo "📦 解析依赖..."
swift package resolve

# 构建
echo "🔧 编译..."
swift build -c release

# 清理旧构建
rm -rf "$APP_BUNDLE"

# 创建 app bundle 结构
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# 复制 Info.plist
cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OhMySkill</string>
    <key>CFBundleIdentifier</key>
    <string>com.ohmyskill.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OhMySkill</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 复制可执行文件
cp ".build/release/$APP_NAME" "$MACOS/"

echo "✅ 构建成功: $APP_BUNDLE"
echo ""
echo "🚀 运行: open $APP_BUNDLE"
