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
        let libUsbDestinationPath = resourcesDirectory.appendingPathComponent("libusb_shared.dylib")
        
        // 检查目标位置是否已存在hdc工具和libusb_shared.dylib
        let hdcExists = fileManager.fileExists(atPath: hdcDestinationPath.path)
        let libUsbExists = fileManager.fileExists(atPath: libUsbDestinationPath.path)
        
        if hdcExists && libUsbExists {
            print("hdc工具和libusb_shared.dylib已存在于Resources目录")
            // 确保有执行权限
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcDestinationPath.path)
            return
        }
        
        // 搜索可能的hdc工具目录
        let possibleHdcDirectories = [
            // 1. 开发目录下的ResourcesTools/hdc
            Bundle.main.bundlePath + "/../ResourcesTools/hdc",
            // 2. 开发目录下的ResourcesTools/toolchains
            Bundle.main.bundlePath + "/../ResourcesTools/toolchains",
        ]
        
        // 尝试从每个可能的目录复制hdc和libusb_shared.dylib
        for hdcDirectory in possibleHdcDirectories {
            let hdcPath = hdcDirectory + "/hdc"
            let libUsbPath = hdcDirectory + "/libusb_shared.dylib"
            
            let hdcPathExists = fileManager.fileExists(atPath: hdcPath)
            let libUsbPathExists = fileManager.fileExists(atPath: libUsbPath)
            
            if hdcPathExists && libUsbPathExists {
                do {
                    // 确保目标目录存在
                    try fileManager.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
                    
                    // 复制hdc工具到应用资源目录（如果需要）
                    if !hdcExists {
                        try fileManager.copyItem(atPath: hdcPath, toPath: hdcDestinationPath.path)
                        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcDestinationPath.path)
                        print("hdc工具已从 \(hdcPath) 复制到应用Resources目录")
                    }
                    
                    // 复制libusb_shared.dylib到应用资源目录（如果需要）
                    if !libUsbExists {
                        try fileManager.copyItem(atPath: libUsbPath, toPath: libUsbDestinationPath.path)
                        print("libusb_shared.dylib已从 \(libUsbPath) 复制到应用Resources目录")
                    }
                    
                    return
                } catch {
                    print("复制hdc工具或依赖库失败: \(error)")
                }
            } else if hdcPathExists {
                // 只找到了hdc但没有找到libusb_shared.dylib
                print("在 \(hdcDirectory) 找到hdc但未找到libusb_shared.dylib")
            }
        }
        
        // 如果找不到hdc工具或libusb_shared.dylib，尝试单独寻找hdc
        if !hdcExists {
            let possibleHdcPaths = [
                Bundle.main.bundlePath + "/../ResourcesTools/hdc/hdc",
                Bundle.main.bundlePath + "/../ResourcesTools/toolchains/hdc",
            ]
            
            for hdcPath in possibleHdcPaths {
                if fileManager.fileExists(atPath: hdcPath) {
                    do {
                        // 确保目标目录存在
                        try fileManager.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
                        
                        // 复制hdc工具到应用资源目录
                        try fileManager.copyItem(atPath: hdcPath, toPath: hdcDestinationPath.path)
                        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcDestinationPath.path)
                        
                        print("只有hdc工具已从 \(hdcPath) 复制到应用Resources目录")
                        
                        // 提醒用户可能需要手动处理依赖库
                        print("警告: 未找到libusb_shared.dylib库文件，hdc工具可能无法正常工作")
                        return
                    } catch {
                        print("复制hdc工具失败: \(error)")
                    }
                }
            }
        }
        
        // 如果找不到hdc工具，显示警告
        print("警告: 未找到hdc工具和依赖库。请确保将完整的hdc工具目录放在ResourcesTools目录中")
        
        // 创建一个警告对话框
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "未找到hdc工具和依赖库"
            alert.informativeText = "请确保ResourcesTools/hdc目录中同时包含hdc和libusb_shared.dylib文件"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
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