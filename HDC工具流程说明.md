# HarmonyOS安装工具 HDC命令流程说明

本文档详细说明了HarmonyOS安装工具应用中使用HDC（HarmonyOS Device Connector）工具的完整流程，从初始化、设备检测到应用安装的全过程。

## 1. HDC工具初始化

### 1.1 HDC工具查找

应用启动时，首先需要查找HDC二进制文件的位置：

```swift
// HdcService.swift - findHdcBinary()方法
// 查找顺序：
// 1. 应用程序Resources/hdc/hdc目录
// 2. 开发目录下的ResourcesTools/hdc/hdc
// 3. 开发目录下的ResourcesTools/toolchains/hdc
// 4. 系统路径/usr/local/bin/hdc
```

查找成功后会存储HDC路径并打印：`找到hdc工具: [路径]`

### 1.2 HDC服务启动

找到HDC工具后，启动HDC服务：

```swift
// HdcService.swift - startHdcServer()方法
// 通过执行脚本启动HDC服务
// 关键命令: hdc start-server
```

启动过程的关键步骤：
1. 设置`DYLD_LIBRARY_PATH`环境变量指向HDC所在目录
2. 切换工作目录到HDC目录，确保HDC能找到所需的库文件
3. 设置HDC可执行权限
4. 执行`hdc start-server`命令启动服务

## 2. 设备列表管理

### 2.1 刷新设备列表

应用通过以下命令获取已连接的HarmonyOS设备列表：

```swift
// HdcService.swift - refreshDeviceList()方法
// 通过执行脚本获取设备列表
// 主要命令: hdc list targets
// 备用命令: hdc list（如果主命令失败）
```

命令执行流程：
1. 设置环境变量指向HDC目录
2. 切换工作目录到HDC目录
3. 执行`hdc list targets`命令
4. 如果失败，尝试执行`hdc list`命令

### 2.2 设备列表解析

从HDC命令输出中解析设备信息：

```swift
// HdcService.swift - parseDeviceListOutput()方法
// 解析HDC命令输出的设备列表
```

解析过程：
1. 按行分割HDC命令输出
2. 过滤掉无关行（标题、空行、指令说明等）
3. 解析设备ID和连接状态
4. 将连接状态正常的设备添加到设备列表中
5. 返回设备列表用于UI显示

### 2.3 设备列表存储

解析得到的设备列表存储在`connectedDevices`数组中：

```swift
// HdcService.swift - Device结构体
struct Device: Identifiable, Hashable {
    var id: String { deviceId }
    let deviceId: String
    let deviceName: String
    let connectionType: String
    // ...
}

// 存储在 @Published var connectedDevices: [Device] = []
```

## 3. 应用安装流程

### 3.1 安装HAP包

当用户选择设备和应用包后，执行安装操作：

```swift
// HdcService.swift - installPackage()方法
// 关键命令: hdc -t [设备ID] install [安装包路径]
```

安装命令执行流程：
1. 设置环境变量指向HDC目录
2. 切换工作目录到HDC目录
3. 执行`hdc -t [设备ID] install [安装包路径]`命令
4. 解析命令输出，确定安装结果

### 3.2 安装结果处理

根据命令执行状态和输出处理安装结果：

```swift
// ContentView.swift - installToDevice()方法
// 处理安装结果，成功或失败
```

结果处理逻辑：
1. 检查命令退出状态
2. 分析命令输出内容
3. 对特定错误（如连接问题）提供专门的处理
4. 向用户显示结果状态

## 4. 错误处理

应用中对HDC相关错误的处理机制：

### 4.1 HDC工具不存在

如果找不到HDC工具：
1. 显示错误对话框提示用户
2. 提供手动选择HDC工具的选项

### 4.2 设备连接问题

当出现`"Not match target"`或`"check connect-key"`错误时：
1. 显示专门的连接错误提示
2. 提供可能的解决方案（检查设备授权、重新连接等）

### 4.3 安装失败

安装失败时会提供具体的错误信息和可能的解决方案。

## 5. 文件处理流程

### 5.1 文件验证

应用验证所选文件是否为有效的HarmonyOS安装包：

```swift
// FileDropService.swift - isValidHarmonyPackage()方法
// 检查文件扩展名是否为.hap
```

### 5.2 文件拖放与选择

应用支持通过两种方式选择HAP文件：
1. 拖放文件到指定区域
2. 点击文件选择区域打开文件选择器

## 6. 用户界面交互

应用界面与HDC流程的交互：
1. 显示已连接设备列表
2. 显示所选安装包信息
3. 提供安装按钮
4. 显示操作状态和结果

## 7. 注意事项与常见问题

### 7.1 HDC工具依赖

HDC工具需要在正确的目录环境中运行才能找到所需的库文件和配置文件。

### 7.2 设备授权

HarmonyOS设备首次连接时需要在设备上授权USB调试权限。

### 7.3 连接问题排查

当出现连接问题时的排查步骤：
1. 检查设备是否处于开发者模式
2. 检查设备上是否有授权提示
3. 重新连接USB线缆
4. 检查HDC工具是否可以正常运行 