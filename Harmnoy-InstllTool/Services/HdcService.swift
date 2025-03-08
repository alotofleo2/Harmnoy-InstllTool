import Foundation

class HdcService: ObservableObject {
    @Published var connectedDevices: [Device] = []
    @Published var isServiceRunning: Bool = false
    @Published var lastError: String? = nil
    
    private var hdcBinaryPath: String?
    private let hdcServerProcess: Process = Process()
    
    struct Device: Identifiable, Hashable {
        var id: String { deviceId }
        let deviceId: String
        let deviceName: String
        let connectionType: String // USB, WiFi等
        
        static func == (lhs: Device, rhs: Device) -> Bool {
            return lhs.deviceId == rhs.deviceId
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(deviceId)
        }
    }
    
    init() {
        // 找到hdc二进制文件
        findHdcBinary()
    }
    
    /// 查找hdc二进制文件
    private func findHdcBinary() {
        // 在应用Bundle中找到hdc二进制文件
        if let hdcPath = Bundle.main.path(forResource: "hdc", ofType: nil) {
            self.hdcBinaryPath = hdcPath
            print("找到hdc工具: \(hdcPath)")
            return
        }
        
        // 如果没有找到，尝试在开发时的路径列表中查找
        let possibleHdcPaths = [
            // 1. 应用程序Resources目录中
            Bundle.main.bundlePath + "/Contents/Resources/hdc",
            // 2. 开发目录下的ResourcesTools/hdc目录
            Bundle.main.bundlePath + "/../ResourcesTools/hdc/hdc",
            // 3. 开发目录下的ResourcesTools/hdc文件
            Bundle.main.bundlePath + "/../ResourcesTools/hdc",
            // 4. 开发目录下的ResourcesTools/toolchains/hdc
            Bundle.main.bundlePath + "/../ResourcesTools/toolchains/hdc",
            // 5. 检查系统路径
            "/usr/local/bin/hdc",
            // 6. toolchains其他可能位置
            Bundle.main.bundlePath + "/../ResourcesTools/toolchains/bin/hdc",
        ]
        
        let fileManager = FileManager.default
        for path in possibleHdcPaths {
            if fileManager.fileExists(atPath: path) {
                self.hdcBinaryPath = path
                print("找到hdc工具: \(path)")
                return
            }
        }
        
        print("警告: 未找到hdc工具。请确保将hdc工具放在ResourcesTools目录中")
        
        // 确保在主线程更新UI相关的@Published属性
        DispatchQueue.main.async { [weak self] in
            self?.lastError = "未找到hdc工具。请确保将hdc工具放在ResourcesTools目录中"
        }
    }
    
    /// 启动hdc服务
    func startHdcServer() {
        guard !isServiceRunning else { return }
        guard let hdcPath = hdcBinaryPath else {
            // 确保在主线程更新UI相关的@Published属性
            DispatchQueue.main.async { [weak self] in
                self?.lastError = "无法启动hdc服务: 未找到hdc工具"
            }
            print("无法启动hdc服务: 未找到hdc工具")
            
            // 重新尝试查找hdc工具
            findHdcBinary()
            return
        }
        
        // 直接执行hdc命令，使用静态链接的库
        do {
            let task = Process()
            
            // 确保hdc工具有执行权限
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcPath)
            
            task.executableURL = URL(fileURLWithPath: hdcPath)
            task.arguments = ["start-server"]
            
            try task.run()
            
            // 设置为正在运行状态
            DispatchQueue.main.async { [weak self] in
                self?.isServiceRunning = true
            }
            
            // 启动服务后刷新设备列表
            DispatchQueue.global(qos: .utility).async {
                task.waitUntilExit()
                
                // 刷新设备列表
                self.refreshDeviceList()
            }
        } catch {
            // 确保在主线程更新UI相关的@Published属性
            DispatchQueue.main.async { [weak self] in
                self?.lastError = "启动hdc服务失败: \(error.localizedDescription)"
            }
            print("启动hdc服务失败: \(error)")
        }
    }
    
    /// 停止hdc服务
    func stopHdcServer() {
        guard isServiceRunning else { return }
        guard let hdcPath = hdcBinaryPath else {
            // 确保在主线程更新UI相关的@Published属性
            DispatchQueue.main.async { [weak self] in
                self?.lastError = "无法停止hdc服务: 未找到hdc工具"
            }
            return
        }
        
        do {
            let task = Process()
            
            // 确保hdc工具有执行权限
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcPath)
            
            task.executableURL = URL(fileURLWithPath: hdcPath)
            task.arguments = ["kill-server"]
            
            try task.run()
            task.waitUntilExit()
            
            // 确保在主线程更新UI相关的@Published属性
            DispatchQueue.main.async { [weak self] in
                self?.isServiceRunning = false
            }
        } catch {
            // 确保在主线程更新UI相关的@Published属性
            DispatchQueue.main.async { [weak self] in
                self?.lastError = "停止hdc服务失败: \(error.localizedDescription)"
            }
            print("停止hdc服务失败: \(error)")
        }
    }
    
    /// 刷新设备列表
    func refreshDeviceList() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let hdcPath = self.hdcBinaryPath else {
                DispatchQueue.main.async {
                    self.lastError = "无法刷新设备列表: 未找到hdc工具"
                }
                return
            }
            
            do {
                let task = Process()
                let pipe = Pipe()
                
                // 确保hdc工具有执行权限
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcPath)
                
                task.standardOutput = pipe
                task.standardError = pipe
                task.executableURL = URL(fileURLWithPath: hdcPath)
                task.arguments = ["list", "devices"]
                
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                
                if let output = String(data: data, encoding: .utf8) {
                    if task.terminationStatus != 0 {
                        throw NSError(domain: "HdcService", code: Int(task.terminationStatus),
                                     userInfo: [NSLocalizedDescriptionKey: "命令执行失败: \(output)"])
                    }
                    
                    // 解析设备列表输出
                    let deviceList = self.parseDeviceListOutput(output)
                    
                    // 确保在主线程更新UI相关的@Published属性
                    DispatchQueue.main.async {
                        self.connectedDevices = deviceList
                        self.lastError = nil
                    }
                } else {
                    throw NSError(domain: "HdcService", code: -1,
                                 userInfo: [NSLocalizedDescriptionKey: "无法解析命令输出"])
                }
            } catch {
                DispatchQueue.main.async {
                    self.lastError = "获取设备列表失败: \(error.localizedDescription)"
                }
                print("获取设备列表失败: \(error)")
            }
        }
    }
    
    /// 安装应用包到指定设备
    func installPackage(packagePath: String, deviceId: String) throws -> String {
        // 直接执行安装命令
        guard let hdcPath = hdcBinaryPath else {
            throw NSError(domain: "HdcService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "未找到hdc工具"])
        }
        
        // 确保hdc工具有执行权限
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcPath)
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.executableURL = URL(fileURLWithPath: hdcPath)
        task.arguments = ["-t", deviceId, "install", packagePath]
        
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        if let output = String(data: data, encoding: .utf8) {
            if task.terminationStatus != 0 {
                throw NSError(domain: "HdcService", code: Int(task.terminationStatus),
                             userInfo: [NSLocalizedDescriptionKey: "命令执行失败: \(output)"])
            }
            return output
        } else {
            throw NSError(domain: "HdcService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "无法解析命令输出"])
        }
    }
    
    /// 卸载应用
    func uninstallPackage(packageName: String, deviceId: String) throws -> String {
        // 直接执行卸载命令
        guard let hdcPath = hdcBinaryPath else {
            throw NSError(domain: "HdcService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "未找到hdc工具"])
        }
        
        // 确保hdc工具有执行权限
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcPath)
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.executableURL = URL(fileURLWithPath: hdcPath)
        task.arguments = ["-t", deviceId, "uninstall", packageName]
        
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        if let output = String(data: data, encoding: .utf8) {
            if task.terminationStatus != 0 {
                throw NSError(domain: "HdcService", code: Int(task.terminationStatus),
                             userInfo: [NSLocalizedDescriptionKey: "命令执行失败: \(output)"])
            }
            return output
        } else {
            throw NSError(domain: "HdcService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "无法解析命令输出"])
        }
    }
    
    /// 解析设备列表输出
    private func parseDeviceListOutput(_ output: String) -> [Device] {
        var devices: [Device] = []
        
        // 按行分割输出
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // 跳过空行和List of devices attached行
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty || trimmedLine.contains("List of devices") {
                continue
            }
            
            // 解析设备信息 (通常格式是: device_id device_state)
            let components = trimmedLine.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            if components.count >= 2 {
                let deviceId = components[0]
                let connectionState = components[1]
                
                // 只添加已连接的设备
                if connectionState == "device" {
                    // 尝试获取设备名称 (实际实现可能需要额外的hdc命令)
                    let deviceName = "HarmonyOS设备" // 在实际开发中,可以获取真实设备名称
                    
                    devices.append(Device(deviceId: deviceId, 
                                         deviceName: deviceName,
                                         connectionType: "USB"))
                }
            }
        }
        
        return devices
    }
} 