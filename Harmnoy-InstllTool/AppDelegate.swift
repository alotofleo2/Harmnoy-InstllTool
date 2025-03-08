import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private let hdcService = HdcService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 应用程序启动完成时调用
        print("应用程序已启动")
        
        // 在启动时拷贝hdc工具到临时目录(如果需要)
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
        // 此方法会在开发阶段检查ResourcesTools目录中是否有hdc工具
        // 如果有,则将其拷贝到应用程序的Resources目录中
        // 在实际发布时,hdc工具应该被直接包含在应用程序包中
        
        let resourcesDirectory = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
        let hdcDestinationPath = resourcesDirectory.appendingPathComponent("hdc")
        
        // 检查目标位置是否已存在hdc工具
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: hdcDestinationPath.path) {
            print("hdc工具已存在")
            return
        }
        
        // 从开发目录复制hdc工具(如果有)
        // 注意:在实际发布时,应该将hdc工具直接包含在构建过程中
        let devToolsPath = Bundle.main.bundlePath + "/../ResourcesTools/hdc"
        if fileManager.fileExists(atPath: devToolsPath) {
            do {
                try fileManager.copyItem(atPath: devToolsPath, toPath: hdcDestinationPath.path)
                
                // 设置执行权限
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcDestinationPath.path)
                
                print("hdc工具已从开发目录复制")
            } catch {
                print("复制hdc工具失败: \(error)")
            }
        } else {
            print("开发目录中未找到hdc工具")
        }
    }
} 