#!/bin/bash

# 脚本名称: build_app.sh
# 功能: 编译打包HarmonyOS安装工具应用程序并生成DMG格式安装包
# 作者: 方焘

# 设置错误处理
set -e

# 显示彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 脚本路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$SCRIPT_DIR"
APP_NAME="Harmnoy-InstllTool"
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT_DIR="$PROJECT_DIR/buildOutput"
DMG_RESOURCES_DIR="$PROJECT_DIR/dmg_resources"

# 显示进度
echo -e "${YELLOW}开始构建 ${APP_NAME}...${NC}"

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"
mkdir -p "$DMG_RESOURCES_DIR"

# 清理旧的构建
echo -e "${YELLOW}清理旧的构建文件...${NC}"
rm -rf "$BUILD_DIR"

# 获取应用版本号
echo -e "${YELLOW}获取应用版本号...${NC}"
cd "$PROJECT_DIR"

# 从Info.plist文件中读取版本号
INFO_PLIST="$PROJECT_DIR/$APP_NAME/Info.plist"
if [ -f "$INFO_PLIST" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0")
    BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "1")
else
    # 尝试使用agvtool作为备选方案
    VERSION=$(xcrun agvtool what-marketing-version -terse1 2>/dev/null || echo "1.0.0")
    BUILD_NUMBER=$(xcrun agvtool what-version -terse 2>/dev/null || echo "1")
fi

FULL_VERSION="${VERSION}.${BUILD_NUMBER}"

echo -e "${GREEN}应用版本: ${FULL_VERSION}${NC}"

# 编译应用
echo -e "${YELLOW}编译应用程序...${NC}"
xcodebuild -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
           -scheme "$APP_NAME" \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           clean build

# 获取编译后的应用路径
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}错误: 应用编译失败或找不到编译后的应用${NC}"
    exit 1
fi

# 创建DMG文件名
DMG_NAME="${APP_NAME}-${FULL_VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
TEMP_DMG_PATH="$BUILD_DIR/tmp_${DMG_NAME}"
MOUNT_POINT="/Volumes/$APP_NAME"
TEMP_DMG_DIR="$BUILD_DIR/tmp_dmg"

# 创建临时DMG目录
echo -e "${YELLOW}创建DMG目录结构...${NC}"
rm -rf "$TEMP_DMG_DIR"
mkdir -p "$TEMP_DMG_DIR"

# 复制应用到临时目录
cp -R "$APP_PATH" "$TEMP_DMG_DIR/"

# 创建指向Applications的符号链接
echo -e "${YELLOW}添加Applications文件夹快捷方式...${NC}"
ln -s /Applications "$TEMP_DMG_DIR/Applications"

# 创建交互式DMG
echo -e "${YELLOW}创建交互式DMG安装包...${NC}"

# 创建一个临时的可读写DMG
hdiutil create -volname "$APP_NAME" \
              -srcfolder "$TEMP_DMG_DIR" \
              -ov -format UDRW \
              "$TEMP_DMG_PATH"

# 挂载DMG以进行自定义
DEV_NAME=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG_PATH" | egrep '^/dev/' | sed 1q | awk '{print $1}')

# 等待DMG挂载完成
sleep 2

# 设置DMG窗口的样式和位置
echo '
tell application "Finder"
    tell disk "'$APP_NAME'"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 800, 500}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set position of item "'$APP_NAME.app'" of container window to {200, 240}
        set position of item "Applications" of container window to {600, 240}
        close
        open
        update without registering applications
        delay 5
    end tell
end tell
' | osascript

# 等待Finder更新
sleep 5

# 卸载DMG
hdiutil detach "$DEV_NAME" -force

# 转换DMG为只读并压缩
hdiutil convert "$TEMP_DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"

# 清理临时文件
rm -f "$TEMP_DMG_PATH"
rm -rf "$TEMP_DMG_DIR"

# 检查DMG文件是否已成功创建
if [ -f "$DMG_PATH" ]; then
    echo -e "${GREEN}DMG安装包已成功创建:${NC}"
    echo -e "${GREEN}$DMG_PATH${NC}"
    # 获取文件大小
    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo -e "${GREEN}文件大小: ${DMG_SIZE}${NC}"
    
    # 创建MD5校验和
    MD5=$(md5 -q "$DMG_PATH")
    echo -e "${GREEN}MD5: ${MD5}${NC}"
    
    # 输出版本信息到文件
    INFO_FILE="$OUTPUT_DIR/${APP_NAME}-${FULL_VERSION}-info.txt"
    echo "应用名称: $APP_NAME" > "$INFO_FILE"
    echo "版本: $FULL_VERSION" >> "$INFO_FILE"
    echo "构建时间: $(date)" >> "$INFO_FILE"
    echo "MD5: $MD5" >> "$INFO_FILE"
    echo "文件大小: $DMG_SIZE" >> "$INFO_FILE"
    
    echo -e "${GREEN}构建信息已保存到: ${INFO_FILE}${NC}"
    echo -e "${GREEN}构建完成!${NC}"
else
    echo -e "${RED}错误: DMG创建失败${NC}"
    exit 1
fi 