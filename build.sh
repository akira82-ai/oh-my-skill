#!/bin/bash

# Oh My Skill 构建脚本
# 用于将 Swift 项目打包为 macOS .app bundle

set -e

# 配置
APP_NAME="OhMySkill"
BUNDLE_ID="com.ohmyskill.app"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 开始构建 $APP_NAME..."

# 清理旧构建
rm -rf "$BUILD_DIR"

# 创建目录结构
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 构建可执行文件
echo "📦 编译 Swift 代码..."
swift build -c release --product OhMySkill

# 复制可执行文件
echo "📋 复制可执行文件..."
cp .build/release/OhMySkill "$MACOS_DIR/$APP_NAME"

# 创建 Info.plist
echo "📝 创建 Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>需要使用 Apple Events 来控制 Claude CLI</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>需要管理员权限来执行某些操作</string>
</dict>
</plist>
EOF

# 可选：代码签名
if [ -n "$CODE_SIGN_IDENTITY" ]; then
    echo "✍️  代码签名..."
    codesign --force --deep --sign "$CODE_SIGN_IDENTITY" "$APP_BUNDLE"
fi

echo "✅ 构建完成！"
echo "📂 应用位置: $APP_BUNDLE"
echo ""
echo "运行应用:"
echo "  open $APP_BUNDLE"
