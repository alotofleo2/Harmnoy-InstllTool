import SwiftUI
import Foundation

// 全局变量来保存URL参数，以便ContentView可以访问
var launchURL: URL? = nil

class AppDelegate: NSObject, NSApplicationDelegate {
    private let hdcService = HdcService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 应用程序启动完成时调用
        print("应用程序启动 - 开始初始化")
        
        // 在启动时设置hdc工具
        setupHdcTool()
        
        // 注册处理AppleEvent事件
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 应用程序将要终止时调用
        print("应用程序即将终止")
        
        // 停止hdc服务
        hdcService.stopHdcServer()
        
        // 注销URL事件处理器
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
    
    // 处理应用程序重新打开的情况，确保只有一个实例
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 将应用置于前台并处理任何待处理的URL
        activateApp()
        
        return true
    }
    
    // 应用程序被打开URL时调用
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        
        print("应用通过URL Scheme打开: \(url)")
        
        handleURLScheme(url)
        
        // 激活应用程序
        activateApp()
    }
    
    // AppleEvent处理器 - 用于捕获URL scheme事件
    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            print("无法从AppleEvent获取URL")
            return
        }
        
        print("通过AppleEvent接收到URL: \(url)")
        handleURLScheme(url)
        activateApp()
    }
    
    // 处理URL Scheme调用
    private func handleURLScheme(_ url: URL) {
        // 检查是否是我们的自定义URL scheme
        if url.scheme?.lowercased() == "fitnessinstaller" {
            // 解析URL参数
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                
                // 查找url参数
                if let urlParam = queryItems.first(where: { $0.name == "url" })?.value {
                    // 保存URL参数到全局变量
                    if let downloadURL = URL(string: urlParam) {
                        print("提取到下载链接: \(urlParam)")
                        launchURL = downloadURL
                        
                        // 通知所有窗口，有URL需要处理
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ProcessURLScheme"),
                            object: downloadURL.absoluteString
                        )
                    }
                }
            }
        }
    }
    
    // 激活应用程序
    private func activateApp() {
        // 主动激活应用，将其置于前台
        NSApp.activate(ignoringOtherApps: true)
        
        // 确保主窗口可见
        if let mainWindow = NSApp.windows.first {
            if !mainWindow.isVisible {
                mainWindow.makeKeyAndOrderFront(nil)
            }
            mainWindow.orderFrontRegardless()
        }
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
