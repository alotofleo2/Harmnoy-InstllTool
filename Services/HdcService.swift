/// 查找hdc二进制文件
private func findHdcBinary() {
    // 查找应用程序Resources目录下的hdc/hdc
    let appHdcPath = Bundle.main.resourcePath! + "/hdc/hdc"
    if FileManager.default.fileExists(atPath: appHdcPath) {
        self.hdcBinaryPath = appHdcPath
        print("找到hdc工具: \(appHdcPath)")
        return
    }
    
    // 如果没有找到，尝试在开发时的路径列表中查找
    let possibleHdcPaths = [
        // 1. 开发目录下的ResourcesTools/hdc目录
        Bundle.main.bundlePath + "/../ResourcesTools/hdc/hdc",
        // 2. 系统路径
        "/usr/local/bin/hdc",
    ]
    
    let fileManager = FileManager.default
    for path in possibleHdcPaths {
        if fileManager.fileExists(atPath: path) {
            self.hdcBinaryPath = path
            print("找到hdc工具: \(path)")
            return
        }
    }
    
    print("错误: 未找到hdc工具。请确保hdc目录及其所有文件已添加到应用程序的Resources目录中")
    
    // 确保在主线程更新UI相关的@Published属性
    DispatchQueue.main.async { [weak self] in
        self?.lastError = "未找到hdc工具。请确保hdc目录已正确包含在应用程序bundle中"
    }
} 