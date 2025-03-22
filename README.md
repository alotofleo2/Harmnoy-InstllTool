# HarmonyOS安装工具 (Harmony Installer)

macOS平台专用的鸿蒙应用（HAP包）安装工具，简化开发者和用户安装鸿蒙应用的流程。

## 系统要求

- 操作系统：macOS 12.15  或更高版本
- 仅支持Mac系统，不支持Windows或Linux

## 安装方法

1. 下载最新版安装包 (DMG文件)
2. 打开DMG文件，将应用拖入Applications文件夹
3. 首次启动可能需要在系统偏好设置中允许应用运行

## 使用方法

### 方法一：通过URL Scheme启动（网页跳转）

可以通过以下URL Scheme格式从网页或其他应用启动安装工具并指定HAP包：

```
Harmonyinstaller://com.leoao.Installer?url=<HAP包URL>
```

例如：
```
Harmonyinstaller://com.leoao.Installer?url=https://example.com/app.hap
```

### 方法二：直接拖拽安装

1. 启动Harmony安装工具
2. 将HAP包文件拖入应用窗口
3. 点击安装按钮

### 方法三：从文件选择器安装

1. 启动Harmony安装工具
2. 点击"打开文件"按钮
3. 在文件选择器中选择HAP包文件
4. 点击安装按钮

## 常见问题

### 首次启动失败

如果应用无法启动，需要在系统安全性设置中允许运行：

1. 前往 系统偏好设置 → 安全性与隐私 → 安全性
2. 点击 "仍要打开" 按钮允许应用运行

### 权限问题

应用需要完全磁盘访问权限才能正常工作：

1. 系统偏好设置 → 安全性与隐私 → 隐私
2. 选择"完全磁盘访问权限" → 解锁 → 勾选"Harmony安装工具"

## 开发者集成

### 网页集成

可以在网页中添加以下HTML代码来提供安装按钮：

```html
<a href="Harmonyinstaller://com.leoao.Installer?url=您的HAP包URL">安装应用</a>
```

### 参数说明

URL Scheme支持的参数：
- `url`: HAP包的下载地址（必填）

## 注意事项

- 仅支持安装符合HarmonyOS规范的HAP包
- 安装过程中请保持网络连接
- 为保证安全，请仅从可信来源下载和安装HAP包

## 版本历史

- v1.0.0：初始版本
