import SwiftUI
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private let hdcService = HdcService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 应用程序启动完成时调用
        print("应用程序启动 - 开始初始化")
        
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
        
        // 应用程序MacOS目录
        let macOSDirectory = Bundle.main.bundlePath + "/Contents"
        let hdcPath = macOSDirectory + "/Resources/hdc"
        
        // 检查MacOS目录中是否存在hdc工具
        if fileManager.fileExists(atPath: hdcPath) {
            // 确保hdc工具有执行权限
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcPath)
            print("找到hdc工具，已设置执行权限: \(hdcPath)")
            
            // 设置其他可执行文件的权限
            let executableFiles = ["diff", "idl", "restool", "rawheap_translator", "ark_disasm", "syscap_tool", "hnpcli"]
            for file in executableFiles {
                let filePath = macOSDirectory + "/\(file)"
                if fileManager.fileExists(atPath: filePath) {
                    try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: filePath)
                    print("已设置\(file)执行权限")
                }
            }
            return
        }
        
        // 如果未找到hdc工具，显示错误
        print("错误: 未在应用程序MacOS目录找到hdc工具")
        print("  - 查找路径: \(hdcPath)")
        print("  - 请确保完整的hdc工具已添加到Xcode项目中")
//        
//        // 创建一个警告对话框
//        DispatchQueue.main.async {
//            let alert = NSAlert()
//            alert.messageText = "未找到hdc工具"
//            alert.informativeText = "应用无法在MacOS目录找到hdc工具。请确保hdc及其所有文件已正确添加到项目中并包含在应用bundle中。"
//            alert.alertStyle = .critical
//            alert.addButton(withTitle: "确定")
//            alert.runModal()
//        }
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
    
    /// 执行命令并返回输出
    private func runCommandWithOutput(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/bash"
        
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        task.waitUntilExit()
        return output
    }
    
    /// 执行命令
    private func runCommand(_ command: String) -> String {
        return runCommandWithOutput(command)
    }
    
    /// 显示错误对话框
    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
} 
