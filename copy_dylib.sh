#!/bin/bash

# 获取目标目录参数
TARGET_BUILD_DIR="$1"
FRAMEWORKS_FOLDER_PATH="$2"

# 打印信息
echo "开始复制libusb_shared.dylib..."
echo "目标构建目录: $TARGET_BUILD_DIR"

# 源文件路径
SOURCE_DYLIB="${SRCROOT}/Harmnoy-InstllTool/Resources/hdc/libusb_shared.dylib"

# 确保源文件存在
if [ ! -f "$SOURCE_DYLIB" ]; then
    echo "错误: 源dylib文件不存在: $SOURCE_DYLIB"
    # 尝试在其他位置查找
    ALTERNATE_SOURCE="${SRCROOT}/ResourcesTools/hdc/libusb_shared.dylib"
    if [ -f "$ALTERNATE_SOURCE" ]; then
        echo "在备选位置找到dylib: $ALTERNATE_SOURCE"
        SOURCE_DYLIB="$ALTERNATE_SOURCE"
    else
        exit 1
    fi
fi

# 目标Resources目录
RESOURCES_DIR="${TARGET_BUILD_DIR}/Contents/Resources/hdc"
if [ ! -d "$RESOURCES_DIR" ]; then
    echo "创建Resources/hdc目录: $RESOURCES_DIR"
    mkdir -p "$RESOURCES_DIR"
fi

# 目标文件路径
TARGET_DYLIB="${RESOURCES_DIR}/libusb_shared.dylib"

# 复制文件
echo "正在复制dylib从 $SOURCE_DYLIB 到 $TARGET_DYLIB"
cp -f "$SOURCE_DYLIB" "$TARGET_DYLIB"

# 检查复制操作是否成功
if [ ! -f "$TARGET_DYLIB" ]; then
    echo "错误: 复制libusb_shared.dylib失败"
    exit 1
fi

# 设置权限
chmod 755 "$TARGET_DYLIB"
echo "已设置文件权限"

# 获取应用程序的签名身份
SIGN_IDENTITY=$(codesign -dvv "${TARGET_BUILD_DIR}/${PRODUCT_NAME}.app" 2>&1 | grep "Authority" | head -1 | cut -d'=' -f2 | xargs)

if [ -n "$SIGN_IDENTITY" ]; then
    echo "使用身份 '$SIGN_IDENTITY' 对动态库进行签名"
    
    # 移除现有签名
    codesign --remove-signature "$TARGET_DYLIB" 2>/dev/null || true
    
    # 重新签名
    if codesign --force --sign "$SIGN_IDENTITY" --timestamp=none --preserve-metadata=identifier,entitlements,requirements "$TARGET_DYLIB"; then
        echo "动态库签名成功"
        
        # 验证签名
        if codesign -vv "$TARGET_DYLIB"; then
            echo "动态库签名验证成功"
            
            # 显示签名详情
            codesign -dvv "$TARGET_DYLIB"
        else
            echo "警告: 动态库签名验证失败"
            exit 1
        fi
    else
        echo "错误: 动态库签名失败"
        exit 1
    fi
else
    echo "警告: 未找到签名身份，跳过签名步骤"
fi

# 设置安装名称
install_name_tool -id "@rpath/libusb_shared.dylib" "$TARGET_DYLIB"
if [ $? -eq 0 ]; then
    echo "已更新动态库安装名称"
else
    echo "警告: 更新动态库安装名称失败"
fi

echo "libusb_shared.dylib处理完成"
exit 0 