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
        let resourcesDirectory = Bundle.main.resourceURL!
        let hdcPath = resourcesDirectory.appendingPathComponent("hdc/hdc").path
        
        // 检查Resources目录中是否存在hdc工具
        if fileManager.fileExists(atPath: hdcPath) {
            // 确保hdc工具有执行权限
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcPath)
            print("找到hdc工具，已设置执行权限: \(hdcPath)")
            
            // 设置其他可执行文件的权限
            let executableFiles = ["diff", "idl", "restool", "rawheap_translator", "ark_disasm", "syscap_tool", "hnpcli"]
            for file in executableFiles {
                let filePath = resourcesDirectory.appendingPathComponent("hdc/\(file)").path
                if fileManager.fileExists(atPath: filePath) {
                    try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: filePath)
                    print("已设置\(file)执行权限")
                }
            }
            return
        }
        
        // 如果未找到hdc工具，显示错误
        print("错误: 未在应用程序Resources目录找到hdc工具目录")
        print("  - 查找路径: \(hdcPath)")
        print("  - 请确保完整的hdc工具目录已添加到Xcode项目的Resources中")
        
        // 创建一个错误对话框
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "未找到hdc工具"
            alert.informativeText = "应用无法在Resources目录找到hdc工具。请确保hdc目录及其所有文件已正确添加到项目中并包含在应用bundle中。"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
} 