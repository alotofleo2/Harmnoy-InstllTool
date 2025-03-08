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
        
        // 目标位置 - 应用程序Resources目录中的hdc
        let resourcesDirectory = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
        let hdcDestinationPath = resourcesDirectory.appendingPathComponent("hdc")
        
        // 检查目标位置是否已存在hdc工具
        if fileManager.fileExists(atPath: hdcDestinationPath.path) {
            print("hdc工具已存在于Resources目录")
            // 确保有执行权限
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcDestinationPath.path)
            
            // 检查依赖项
            checkAndHandleDependencies(forHdcAt: hdcDestinationPath.path)
            return
        }
        
        // 搜索可能的hdc工具位置
        let possibleHdcPaths = [
            // 1. 开发目录下的ResourcesTools/hdc
            Bundle.main.bundlePath + "/../ResourcesTools/hdc/hdc",
            // 2. 开发目录下的ResourcesTools/hdc (没有子目录)
            Bundle.main.bundlePath + "/../ResourcesTools/hdc",
            // 3. 开发目录下的ResourcesTools/toolchains中
            Bundle.main.bundlePath + "/../ResourcesTools/toolchains/hdc",
            // 4. 用户可能将文件放在toolchains根目录
            Bundle.main.bundlePath + "/../ResourcesTools/toolchains/hdc",
        ]
        
        // 尝试每个可能的路径
        for hdcPath in possibleHdcPaths {
            if fileManager.fileExists(atPath: hdcPath) {
                do {
                    // 确保目标目录存在
                    try fileManager.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
                    
                    // 复制hdc工具到应用资源目录
                    try fileManager.copyItem(atPath: hdcPath, toPath: hdcDestinationPath.path)
                    
                    // 设置执行权限
                    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcDestinationPath.path)
                    
                    print("hdc工具已从 \(hdcPath) 复制到应用Resources目录")
                    
                    // 检查和处理依赖项
                    checkAndHandleDependencies(forHdcAt: hdcDestinationPath.path)
                    return
                } catch {
                    print("复制hdc工具失败: \(error)")
                }
            }
        }
        
        // 如果找不到hdc工具，显示警告
        print("警告: 未找到hdc工具。请确保将hdc工具放在ResourcesTools目录中")
        
        // 创建一个警告对话框
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "未找到hdc工具"
            alert.informativeText = "请将hdc工具放在以下路径之一:\n1. ResourcesTools/hdc/hdc\n2. ResourcesTools/hdc\n3. ResourcesTools/toolchains/hdc"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
    
    /// 检查hdc依赖项并处理
    private func checkAndHandleDependencies(forHdcAt hdcPath: String) {
        // 检查是否有libusb_shared.dylib依赖
        let resourcesDirectory = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
        let libUsbPath = resourcesDirectory.appendingPathComponent("libusb_shared.dylib")
        
        // 如果已经存在libusb_shared.dylib，就不需要再复制
        if FileManager.default.fileExists(atPath: libUsbPath.path) {
            print("libusb_shared.dylib已存在")
            return
        }
        
        // 查找可能的libusb_shared.dylib路径
        let possibleLibPaths = [
            // 1. 在hdc工具所在目录
            URL(fileURLWithPath: hdcPath).deletingLastPathComponent().appendingPathComponent("libusb_shared.dylib").path,
            // 2. 在ResourcesTools/lib目录
            Bundle.main.bundlePath + "/../ResourcesTools/lib/libusb_shared.dylib",
            // 3. 在ResourcesTools/toolchains/lib目录
            Bundle.main.bundlePath + "/../ResourcesTools/toolchains/lib/libusb_shared.dylib",
        ]
        
        // 尝试复制找到的第一个libusb_shared.dylib
        for libPath in possibleLibPaths {
            if FileManager.default.fileExists(atPath: libPath) {
                do {
                    try FileManager.default.copyItem(atPath: libPath, toPath: libUsbPath.path)
                    print("libusb_shared.dylib已从 \(libPath) 复制到应用Resources目录")
                    return
                } catch {
                    print("复制libusb_shared.dylib失败: \(error)")
                }
            }
        }
        
        print("警告: 未找到libusb_shared.dylib库文件。hdc工具可能无法正常工作。")
        print("尝试使用替代方法启动hdc服务...")
    }
    
    /// 获取hdc工具路径
    private func getHdcToolPath() -> String? {
        // 首先检查应用Resources目录
        if let hdcPath = Bundle.main.path(forResource: "hdc", ofType: nil) {
            return hdcPath
        }
        
        // 然后检查开发目录
        let fileManager = FileManager.default
        let possibleHdcPaths = [
            Bundle.main.bundlePath + "/../ResourcesTools/hdc/hdc",
            Bundle.main.bundlePath + "/../ResourcesTools/hdc",
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