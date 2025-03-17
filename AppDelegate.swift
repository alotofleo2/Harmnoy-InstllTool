import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private let hdcService = HdcService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("应用程序启动 - 开始初始化")
        setupHdcTool()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("应用程序即将终止")
        hdcService.stopHdcServer()
    }
    
    private func setupHdcTool() {
        let fileManager = FileManager.default
        
        // 获取应用程序包路径
        guard let bundle = Bundle.main.bundleURL else {
            print("错误: 无法获取应用程序包路径")
            showError(message: "无法获取应用程序路径")
            return
        }
        
        // 构建hdc工具路径
        let resourcesDirectory = bundle.appendingPathComponent("Contents/Resources/hdc")
        let hdcPath = resourcesDirectory.appendingPathComponent("hdc").path
        
        print("初始化信息:")
        print("- 应用程序包路径: \(bundle.path)")
        print("- Resources目录: \(resourcesDirectory.path)")
        print("- HDC工具路径: \(hdcPath)")
        
        // 检查目录是否存在
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: resourcesDirectory.path, isDirectory: &isDirectory) {
            print("错误: Resources/hdc目录不存在")
            showError(message: "找不到hdc工具目录")
            return
        }
        
        if !isDirectory.boolValue {
            print("错误: Resources/hdc不是一个目录")
            showError(message: "hdc工具目录结构错误")
            return
        }
        
        // 检查hdc工具
        if !fileManager.fileExists(atPath: hdcPath) {
            print("错误: hdc工具不存在于路径: \(hdcPath)")
            showError(message: "找不到hdc工具")
            return
        }
        
        // 检查动态库
        let dyLibPath = resourcesDirectory.appendingPathComponent("libusb_shared.dylib").path
        if !fileManager.fileExists(atPath: dyLibPath) {
            print("错误: 找不到libusb_shared.dylib: \(dyLibPath)")
            showError(message: "找不到必要的动态库")
            return
        }
        
        // 设置执行权限
        do {
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcPath)
            print("已设置hdc工具执行权限")
            
            // 设置动态库权限
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dyLibPath)
            print("已设置动态库执行权限")
            
            // 设置其他工具权限
            let executableFiles = ["diff", "idl", "restool", "rawheap_translator", "ark_disasm", "syscap_tool", "hnpcli"]
            for file in executableFiles {
                let filePath = resourcesDirectory.appendingPathComponent(file).path
                if fileManager.fileExists(atPath: filePath) {
                    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: filePath)
                    print("已设置\(file)执行权限")
                }
            }
        } catch {
            print("错误: 设置文件权限失败: \(error.localizedDescription)")
            showError(message: "无法设置工具执行权限")
            return
        }
        
        // 设置环境变量
        setenv("DYLD_LIBRARY_PATH", resourcesDirectory.path, 1)
        print("已设置DYLD_LIBRARY_PATH: \(resourcesDirectory.path)")
        
        print("HDC工具初始化完成")
    }
    
    private func showError(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "初始化错误"
            alert.informativeText = message
            alert.runModal()
        }
    }
} 