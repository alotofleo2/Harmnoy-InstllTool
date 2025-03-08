# HarmonyOS安装工具

这是一个macOS应用程序,用于简化HarmonyOS应用包(.hap)的安装过程。通过图形界面,用户可以轻松将应用安装到连接的HarmonyOS设备上。

## 功能特性

1. 拖放式安装包导入功能
2. 自动检测已连接的HarmonyOS设备
3. 一键安装应用到选定设备
4. 集成hdc工具,无需额外安装

## 开发准备

### 环境要求
- macOS 12.0 或更高版本
- Xcode 14.0 或更高版本
- Swift 5.7 或更高版本

### 获取hdc工具
hdc (HarmonyOS Device Connector) 是华为开发的用于连接和管理HarmonyOS设备的命令行工具。您可以通过以下方式获取：

1. 从[华为开发者联盟网站](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hdc)下载
2. 从HarmonyOS SDK包中提取（通常位于SDK的toolchains目录下）

### 配置hdc工具
获取hdc工具后，您有以下几种方式配置：

#### 方式1: 开发阶段手动配置（推荐）
1. 将hdc工具放入项目根目录下的`ResourcesTools/hdc`文件夹中
   ```
   ResourcesTools/
   └── hdc        # 直接放置hdc可执行文件
   ```

#### 方式2: 在应用程序中手动选择
1. 启动应用程序
2. 如果应用程序提示"未找到hdc工具"，点击"选择hdc工具"按钮
3. 在文件选择对话框中选择hdc可执行文件

#### 方式3: 使用toolchains包
如果您有完整的toolchains包，可以将其放置在以下位置：
```
ResourcesTools/
└── toolchains/
    ├── bin/
    │   └── hdc    # hdc可执行文件
    └── ...        # 其他toolchains文件
```

### 开发设置
1. 配置好hdc工具
2. 打开Xcode项目并构建运行

## 使用方法

1. 通过数据线将HarmonyOS设备连接到Mac
2. 启动应用程序
3. 将.hap安装包拖入应用窗口或点击窗口选择文件
4. 等待设备被识别(可点击刷新按钮刷新设备列表)
5. 点击对应设备的"安装"按钮,将应用安装到该设备

## 技术实现

- 使用SwiftUI开发用户界面
- 通过集成hdc命令行工具实现与设备的通信
- 采用响应式设计,实时更新安装状态和设备连接信息

## 注意事项

- 首次使用时,macOS可能会请求访问权限,请允许相关权限以确保功能正常
- 请确保设备已开启开发者选项和USB调试模式
- 安装过程需要保持设备连接

## 故障排除

如果遇到"未找到hdc工具"错误，请尝试以下解决方法：

1. 确保hdc工具已正确放置在ResourcesTools目录的正确位置
2. 使用应用程序中的"选择hdc工具"功能手动指定hdc工具位置
3. 确保hdc工具具有执行权限（chmod +x path/to/hdc）
4. 重启应用程序 