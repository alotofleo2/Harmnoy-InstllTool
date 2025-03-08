import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private let hdcService = HdcService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 应用程序启动完成时调用
        print("应用程序已启动")
        
        // 在启动时设置hdc工具
        setupHdcTool()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 应用程序将要终止时调用
        print("应用程序即将终止")
        
        // 停止hdc服务
        hdcService.stopHdcServer()
    }
    
    /// 设置hdc工具
    private func setupHdcTool() {
        let fileManager = FileManager.default
        
        // 应用程序Resources目录
        let resourcesDirectory = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
        let hdcDestinationDir = resourcesDirectory.appendingPathComponent("hdc")
        
        // 检查目标位置是否已存在hdc工具目录
        if fileManager.fileExists(atPath: hdcDestinationDir.path) {
            // 确保hdc工具有执行权限
            let hdcExecutablePath = hdcDestinationDir.appendingPathComponent("hdc").path
            if fileManager.fileExists(atPath: hdcExecutablePath) {
                try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcExecutablePath)
                print("hdc工具目录已存在于Resources目录，已确保hdc有执行权限")
                return
            }
        }
        
        // 搜索可能的hdc工具目录
        let possibleHdcDirectories = [
            Bundle.main.bundlePath + "/../ResourcesTools/hdc",
            Bundle.main.bundlePath + "/../ResourcesTools/toolchains",
        ]
        
        // 尝试找到并复制整个hdc目录
        for sourceDir in possibleHdcDirectories {
            // 检查源目录是否存在
            if fileManager.fileExists(atPath: sourceDir) && 
               (fileManager.fileExists(atPath: sourceDir + "/hdc") || 
                sourceDir.hasSuffix("/hdc")) {
                
                // 要复制的源目录
                var sourceDirToCopy = sourceDir
                
                // 如果是/toolchains目录，我们需要检查是否包含hdc文件，如果不包含，则可能不是我们要的目录
                if sourceDir.hasSuffix("/toolchains") {
                    if !fileManager.fileExists(atPath: sourceDir + "/hdc") {
                        print("toolchains目录不包含hdc工具，跳过")
                        continue
                    }
                }
                
                do {
                    // 如果目标目录已存在，先删除它
                    if fileManager.fileExists(atPath: hdcDestinationDir.path) {
                        try fileManager.removeItem(at: hdcDestinationDir)
                    }
                    
                    // 确保父目录存在
                    try fileManager.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
                    
                    // 如果是ResourcesTools/hdc，则复制整个目录
                    if sourceDir.hasSuffix("/hdc") {
                        try fileManager.copyItem(atPath: sourceDirToCopy, toPath: hdcDestinationDir.path)
                        print("已复制整个hdc目录到: \(hdcDestinationDir.path)")
                    } 
                    // 如果是toolchains目录且包含hdc，则复制hdc及相关文件
                    else if fileManager.fileExists(atPath: sourceDir + "/hdc") {
                        // 创建目标hdc目录
                        try fileManager.createDirectory(at: hdcDestinationDir, withIntermediateDirectories: true)
                        
                        // 复制hdc可执行文件
                        try fileManager.copyItem(atPath: sourceDir + "/hdc", toPath: hdcDestinationDir.appendingPathComponent("hdc").path)
                        
                        // 复制libusb_shared.dylib如果存在
                        if fileManager.fileExists(atPath: sourceDir + "/libusb_shared.dylib") {
                            try fileManager.copyItem(atPath: sourceDir + "/libusb_shared.dylib", toPath: hdcDestinationDir.appendingPathComponent("libusb_shared.dylib").path)
                        }
                        
                        // 复制其他可能需要的目录
                        let possibleDirsToInclude = ["lib", "configcheck", "modulecheck", "syscapcheck"]
                        for dirName in possibleDirsToInclude {
                            let sourcePath = "\(sourceDir)/\(dirName)"
                            if fileManager.fileExists(atPath: sourcePath) {
                                try fileManager.copyItem(atPath: sourcePath, toPath: hdcDestinationDir.appendingPathComponent(dirName).path)
                            }
                        }
                        
                        print("已从toolchains复制hdc及相关文件到: \(hdcDestinationDir.path)")
                    }
                    
                    // 确保hdc工具有执行权限
                    let hdcExecutablePath = hdcDestinationDir.appendingPathComponent("hdc").path
                    if fileManager.fileExists(atPath: hdcExecutablePath) {
                        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcExecutablePath)
                        print("已设置hdc工具执行权限")
                        
                        // 设置其他可执行文件的权限
                        let executableFiles = ["diff", "idl", "restool", "rawheap_translator", "ark_disasm", "syscap_tool", "hnpcli"]
                        for file in executableFiles {
                            let filePath = hdcDestinationDir.appendingPathComponent(file).path
                            if fileManager.fileExists(atPath: filePath) {
                                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: filePath)
                            }
                        }
                        
                        return // 成功完成复制，退出函数
                    }
                } catch {
                    print("复制hdc目录失败: \(error)")
                }
            }
        }
        
        // 如果未能找到并复制hdc目录，显示警告
        print("警告: 未找到hdc工具目录。请确保ResourcesTools/hdc目录存在且包含完整的工具集")
        
        // 创建一个警告对话框
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "未找到hdc工具目录"
            alert.informativeText = "请确保ResourcesTools/hdc目录存在且包含完整的工具集。hdc工具需要访问其目录下的其他工具才能正常工作。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
    
    /// 获取hdc工具路径
    private func getHdcToolPath() -> String? {
        // 首先检查应用Resources目录
        let resourcesPath = Bundle.main.bundlePath + "/Contents/Resources/hdc/hdc"
        if FileManager.default.fileExists(atPath: resourcesPath) {
            return resourcesPath
        }
        
        // 然后检查开发目录
        let fileManager = FileManager.default
        let possibleHdcPaths = [
            Bundle.main.bundlePath + "/../ResourcesTools/hdc/hdc",
            Bundle.main.bundlePath + "/../ResourcesTools/toolchains/hdc",
        ]
        
        for path in possibleHdcPaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
} 