import Foundation
import AppKit  // 添加AppKit导入以使用NSApp

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
        // 优先查找应用程序MacOS目录下的hdc
        let appHdcPath = Bundle.main.bundlePath + "/Contents/Resources/hdc"
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
        
        print("警告: 未找到hdc工具。请确保将hdc工具放在正确的位置")
        
        // 确保在主线程更新UI相关的@Published属性
        DispatchQueue.main.async { [weak self] in
            self?.lastError = "未找到hdc工具。请确保将hdc工具放在正确的位置"
        }
    }
    
    /// 获取hdc工具所在目录
    private func getHdcDirectory() -> String? {
        guard let hdcPath = hdcBinaryPath else { return nil }
        // 现在工具都在 MacOS 目录下，直接返回该目录
        return Bundle.main.bundlePath + "/Contents/Resources"
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
        
        // 使用脚本方法执行hdc命令，设置DYLD_LIBRARY_PATH指向hdc所在目录
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        // 获取hdc工具所在目录
        let hdcDirectory = getHdcDirectory() ?? (URL(fileURLWithPath: hdcPath).deletingLastPathComponent().path)
        
        // 创建一个临时脚本来设置必要的环境变量并运行hdc
        let tempScriptPath = NSTemporaryDirectory() + "run_hdc_\(UUID().uuidString).sh"
        let scriptContent = """
        #!/bin/bash
        # 设置DYLD_LIBRARY_PATH指向hdc所在目录
        export DYLD_LIBRARY_PATH="\(hdcDirectory)"
        # 设置工作目录为hdc目录，以便hdc可以找到其需要的其他文件
        cd "\(hdcDirectory)"
        
        # 确保hdc有执行权限
        chmod +x "\(hdcPath)"
        
        # 运行hdc命令
        "\(hdcPath)" start-server
        
        exit $?
        """
        
        do {
            try scriptContent.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptPath)
            
            task.arguments = [tempScriptPath]
            try task.run()
            
            // 设置为正在运行状态
            DispatchQueue.main.async { [weak self] in
                self?.isServiceRunning = true
            }
            
            // 清理临时脚本
            DispatchQueue.global(qos: .utility).async {
                task.waitUntilExit()
                try? FileManager.default.removeItem(atPath: tempScriptPath)
                
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
        
        // 获取hdc工具所在目录
        let hdcDirectory = getHdcDirectory() ?? (URL(fileURLWithPath: hdcPath).deletingLastPathComponent().path)
        
        // 使用脚本方法停止服务
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        let tempScriptPath = NSTemporaryDirectory() + "stop_hdc_\(UUID().uuidString).sh"
        let scriptContent = """
        #!/bin/bash
        # 设置DYLD_LIBRARY_PATH指向hdc所在目录
        export DYLD_LIBRARY_PATH="\(hdcDirectory)"
        # 设置工作目录为hdc目录
        cd "\(hdcDirectory)"
        
        # 确保hdc有执行权限
        chmod +x "\(hdcPath)"
        
        # 运行hdc命令
        "\(hdcPath)" kill-server
        
        exit $?
        """
        
        do {
            try scriptContent.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptPath)
            
            task.arguments = [tempScriptPath]
            try task.run()
            task.waitUntilExit()
            
            // 清理临时脚本
            try? FileManager.default.removeItem(atPath: tempScriptPath)
            
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
            
            // 获取hdc工具所在目录
            let hdcDirectory = self.getHdcDirectory() ?? (URL(fileURLWithPath: hdcPath).deletingLastPathComponent().path)
            print("刷新设备列表: 使用hdc目录 \(hdcDirectory)")
            
            do {
                // 使用脚本方法执行hdc命令
                let tempScriptPath = NSTemporaryDirectory() + "list_devices_\(UUID().uuidString).sh"
                let scriptContent = """
                #!/bin/bash
                # 设置DYLD_LIBRARY_PATH指向hdc所在目录
                export DYLD_LIBRARY_PATH="\(hdcDirectory)"
                # 设置工作目录为hdc目录
                cd "\(hdcDirectory)"
                
                # 确保hdc有执行权限
                chmod +x "\(hdcPath)"
                
                # 打印当前环境变量
                echo "环境变量: DYLD_LIBRARY_PATH=$DYLD_LIBRARY_PATH"
                echo "当前目录: $(pwd)"
                echo "运行: \(hdcPath) list targets"
                
                # 运行hdc命令 - HarmonyOS使用list targets而不是list devices
                "\(hdcPath)" list targets
                
                # 如果上面的命令失败，尝试替代命令
                if [ $? -ne 0 ]; then
                    echo "尝试替代命令: \(hdcPath) list"
                    "\(hdcPath)" list
                fi
                
                exit $?
                """
                
                try scriptContent.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptPath)
                
                let task = Process()
                let pipe = Pipe()
                
                task.standardOutput = pipe
                task.standardError = pipe
                task.executableURL = URL(fileURLWithPath: "/bin/bash")
                task.arguments = [tempScriptPath]
                
                print("执行设备列表脚本: \(tempScriptPath)")
                try task.run()
                task.waitUntilExit()
                
                // 清理临时脚本
                try? FileManager.default.removeItem(atPath: tempScriptPath)
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                
                if let output = String(data: data, encoding: .utf8) {
                    print("设备列表命令结果状态: \(task.terminationStatus)")
                    
                    if task.terminationStatus != 0 {
                        throw NSError(domain: "HdcService", code: Int(task.terminationStatus),
                                     userInfo: [NSLocalizedDescriptionKey: "命令执行失败: \(output)"])
                    }
                    
                    // 解析设备列表输出
                    let deviceList = self.parseDeviceListOutput(output)
                    
                    // 确保在主线程更新UI相关的@Published属性
                    DispatchQueue.main.async {
                        print("更新UI: 发现 \(deviceList.count) 个设备")
                        self.connectedDevices = deviceList
                        
                        // 更新错误信息，如果设备列表为空但没有其他错误，设置友好的提示信息
                        if deviceList.isEmpty && output.contains("[Empty]") {
                            self.lastError = "未检测到连接的设备。请确保设备已通过USB连接并已打开调试模式。"
                        } else {
                            self.lastError = nil
                        }
                    }
                } else {
                    throw NSError(domain: "HdcService", code: -1,
                                 userInfo: [NSLocalizedDescriptionKey: "无法解析命令输出"])
                }
            } catch {
                print("获取设备列表错误: \(error)")
                DispatchQueue.main.async {
                    self.lastError = "获取设备列表失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// 安装应用包到指定设备
    func installPackage(packagePath: String, deviceId: String) throws -> String {
        guard let hdcPath = hdcBinaryPath else {
            throw NSError(domain: "HdcService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法启动hdc服务: 未找到hdc工具"])
        }
        
        print("开始使用鸿蒙IDE方式安装...")
        
        // 获取hdc工具所在目录
        let hdcDirectory = getHdcDirectory() ?? (URL(fileURLWithPath: hdcPath).deletingLastPathComponent().path)
        
        // 查找或准备HAP文件
        let hapPath: String
        var tempExtractDir: String? = nil
        
        // 检查是否直接是HAP文件
        if packagePath.lowercased().hasSuffix(".hap") {
            hapPath = packagePath
            print("直接使用HAP文件: \(hapPath)")
        } else {
            // 检查是否是ZIP文件
            let fileType = runCommandWithOutput("/usr/bin/file", args: [packagePath])
            if fileType.contains("Zip archive") {
                // 解压ZIP文件
                tempExtractDir = NSTemporaryDirectory() + "HapExtract_" + UUID().uuidString
                try FileManager.default.createDirectory(atPath: tempExtractDir!, withIntermediateDirectories: true, attributes: nil)
                
                print("解压应用包到: \(tempExtractDir!)")
                let unzipResult = runCommandWithOutput("/usr/bin/unzip", args: ["-o", packagePath, "-d", tempExtractDir!])
                print("解压结果: \(unzipResult.prefix(200))...")
                
                // 在解压目录中查找HAP文件
                if let foundHapPath = findHapInExtractedDir(tempExtractDir!) {
                    hapPath = foundHapPath
                    print("在解压目录中找到HAP文件: \(hapPath)")
                } else {
                    throw NSError(domain: "HdcService", code: 2, userInfo: [NSLocalizedDescriptionKey: "未在解压目录中找到HAP文件"])
                }
            } else {
                // 如果是目录，尝试在其中查找HAP文件
                if let foundHapPath = findHapFile(in: packagePath) {
                    hapPath = foundHapPath
                    print("在路径中找到HAP文件: \(hapPath)")
                } else {
                    throw NSError(domain: "HdcService", code: 2, userInfo: [NSLocalizedDescriptionKey: "未找到有效的HAP文件"])
                }
            }
        }
        
        // 确保文件可访问
        if !FileManager.default.isReadableFile(atPath: hapPath) {
            throw NSError(domain: "HdcService", code: 3, userInfo: [NSLocalizedDescriptionKey: "HAP文件无法访问: \(hapPath)"])
        }
        
        // 从文件名或内容推测包ID
        let bundleId = extractBundleId(from: hapPath)
        print("使用包ID: \(bundleId)")
        
        // 创建临时脚本
        let tempScriptDir = NSTemporaryDirectory() + "HdcScripts"
        try FileManager.default.createDirectory(atPath: tempScriptDir, withIntermediateDirectories: true, attributes: nil)
        let uuid = UUID().uuidString
        let tempScriptPath = "\(tempScriptDir)/install_app_\(uuid).sh"
        
        // 创建一个随机目录名用于设备上的临时目录
        let randomDirName = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(32)
        let tempDevicePath = "data/local/tmp/\(randomDirName)"
        
        // 创建安装脚本 - 完全按照鸿蒙IDE的命令顺序，但不包括启动应用
        let scriptContent = """
        #!/bin/bash
        # 设置DYLD_LIBRARY_PATH指向hdc所在目录
        export DYLD_LIBRARY_PATH="\(hdcDirectory)"
        # 设置工作目录为hdc目录
        cd "\(hdcDirectory)"
        
        # 确保hdc有执行权限
        chmod +x "\(hdcPath)"
        
        echo "====== 开始安装应用（鸿蒙IDE方式）======"
        echo "设备ID: \(deviceId)"
        echo "HAP路径: \(hapPath)"
        echo "包ID: \(bundleId)"
        echo "临时目录: \(tempDevicePath)"
        
        # 1. 先停止应用
        echo "步骤1: 停止应用"
        "\(hdcPath)" -t \(deviceId) shell aa force-stop \(bundleId)
        
        # 2. 在设备上创建临时目录
        echo "步骤2: 创建临时目录"
        "\(hdcPath)" -t \(deviceId) shell mkdir -p \(tempDevicePath)
        
        # 3. 发送HAP文件到设备
        echo "步骤3: 发送HAP文件到设备"
        "\(hdcPath)" -t \(deviceId) file send "\(hapPath)" \(tempDevicePath)
        if [ $? -ne 0 ]; then
            echo "错误: 无法发送HAP文件到设备"
            "\(hdcPath)" -t \(deviceId) shell rm -rf \(tempDevicePath)
            exit 1
        fi
        
        # 4. 安装应用 - 使用bm install命令
        echo "步骤4: 安装应用"
        "\(hdcPath)" -t \(deviceId) shell bm install -p \(tempDevicePath)
        INSTALL_RESULT=$?
        
        # 5. 清理临时文件
        echo "步骤5: 清理临时文件"
        "\(hdcPath)" -t \(deviceId) shell rm -rf \(tempDevicePath)
        
        # 6. 尝试启动应用
        echo "步骤6: 尝试启动应用"
        "\(hdcPath)" -t \(deviceId) shell aa start -a EntryAbility -b \(bundleId)
        # 启动应用的结果不影响整体安装结果
        
        # 检查安装结果，不再尝试启动应用
        if [ $INSTALL_RESULT -eq 0 ]; then
            echo "安装成功 - 应用ID: \(bundleId)"
            exit 0
        else
            echo "安装失败 - 状态码: $INSTALL_RESULT"
            exit 1
        fi
        """
        
        try scriptContent.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptPath)
        
        // 执行脚本
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [tempScriptPath]
        
        try task.run()
        task.waitUntilExit()
        
        // 清理临时目录
        if let extractDir = tempExtractDir {
            try? FileManager.default.removeItem(atPath: extractDir)
        }
        
        // 清理临时脚本
        try? FileManager.default.removeItem(atPath: tempScriptPath)
        
        // 获取输出
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        print("安装脚本输出: \(output)")
        
        // 检查结果
        let statusSuccess = task.terminationStatus == 0
        let outputHasError = output.contains("error:") || 
                             output.contains("fail") || 
                             output.contains("no signature") ||
                             output.contains("failed to install")
        
        // 即使状态码为0，也检查输出是否包含错误信息
        if !statusSuccess || outputHasError {
            var errorMessage = "安装失败"
            if outputHasError, let errorLine = output.components(separatedBy: .newlines).first(where: { 
                $0.contains("error:") || 
                $0.contains("failed to install") || 
                $0.contains("no signature")
            }) {
                errorMessage = "安装失败: \(errorLine.trimmingCharacters(in: .whitespacesAndNewlines))"
            } else if !statusSuccess {
                errorMessage = "安装命令执行失败，状态码: \(task.terminationStatus)"
            }
            
            throw NSError(domain: "HdcService", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        return "Success: 已成功安装应用到设备"
    }
    
    /// 卸载应用
    func uninstallPackage(packageName: String, deviceId: String) throws -> String {
        guard let hdcPath = hdcBinaryPath else {
            throw NSError(domain: "HdcService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "未找到hdc工具"])
        }
        
        // 获取hdc工具所在目录
        let hdcDirectory = getHdcDirectory() ?? (URL(fileURLWithPath: hdcPath).deletingLastPathComponent().path)
        
        // 使用脚本方法执行卸载命令
        let tempScriptPath = NSTemporaryDirectory() + "uninstall_app_\(UUID().uuidString).sh"
        let scriptContent = """
        #!/bin/bash
        # 设置DYLD_LIBRARY_PATH指向hdc所在目录
        export DYLD_LIBRARY_PATH="\(hdcDirectory)"
        # 设置工作目录为hdc目录
        cd "\(hdcDirectory)"
        
        # 确保hdc有执行权限
        chmod +x "\(hdcPath)"
        
        # 运行hdc命令
        "\(hdcPath)" -t "\(deviceId)" uninstall "\(packageName)"
        
        exit $?
        """
        
        try scriptContent.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptPath)
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [tempScriptPath]
        
        try task.run()
        task.waitUntilExit()
        
        // 清理临时脚本
        try? FileManager.default.removeItem(atPath: tempScriptPath)
        
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
        var uniqueDevices: Set<String> = []
        
        // 打印原始输出以便调试
        print("设备列表原始输出:\n\(output)")
        
        // 检查是否输出包含[Empty]，表示没有连接的设备
        if output.contains("[Empty]") {
            print("检测到[Empty]输出，表示没有连接的设备")
            return []
        }
        
        // 按行分割输出
        let lines = output.components(separatedBy: .newlines)
        
        // 标记，从环境变量信息之后开始处理，因为前面都是脚本调试信息
        var startProcessingDevices = false
        
        for line in lines {
            // 跳过空行
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty {
                continue
            }
            
            print("处理行: '\(trimmedLine)'")
            
            // 如果发现运行命令的行，表示设备列表紧随其后
            if trimmedLine.contains("list targets") {
                startProcessingDevices = true
                print("即将开始处理设备列表")
                continue
            }
            
            // 如果尚未到达设备列表部分，跳过
            if !startProcessingDevices {
                print("跳过前导信息: \(trimmedLine)")
                continue
            }
            
            // 跳过辅助信息行
            if trimmedLine.hasPrefix("环境变量:") ||
               trimmedLine.hasPrefix("当前目录:") ||
               trimmedLine.hasPrefix("运行:") ||
               trimmedLine.contains("List of devices") ||
               trimmedLine.contains("OpenHarmony") ||
               trimmedLine.contains("commands") ||
               trimmedLine.hasPrefix("-") ||
               trimmedLine.contains("help") ||
               trimmedLine.contains("Print hdc") ||
               trimmedLine.contains("尝试替代命令") {
                print("跳过辅助信息行: \(trimmedLine)")
                continue
            }
            
            // 分割行，获取设备ID及状态（如果有）
            let components = trimmedLine.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            if components.isEmpty {
                continue
            }
            
            let deviceId = components[0]
            
            // 检查设备ID是否已存在
            if !uniqueDevices.contains(deviceId) {
                uniqueDevices.insert(deviceId)
                
                // 确定设备类型和名称
                var deviceName: String
                var connectionType: String
                
                // 根据ID格式确定设备类型
                if deviceId.contains(":") || (deviceId.contains(".") && deviceId.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil) {
                    // 网络设备
                    if deviceId.contains("127.0.0.1") {
                        deviceName = "本地设备 (通过网络)"
                    } else {
                        deviceName = "网络设备"
                    }
                    connectionType = "网络"
                } else {
                    // 物理设备
                    deviceName = "HarmonyOS物理设备"
                    connectionType = "USB"
                }
                
                // 如果有额外信息，添加到设备名称
                if components.count > 1 {
                    let additionalInfo = components[1..<components.count].joined(separator: " ")
                    if !additionalInfo.isEmpty && additionalInfo != "device" {
                        deviceName += " (\(additionalInfo))"
                    }
                }
                
                // 为序列号类型的设备添加序列号显示
                if connectionType == "USB" {
                    deviceName += " [SN: \(deviceId)]"
                }
                
                print("添加设备: ID=\(deviceId), 名称=\(deviceName), 类型=\(connectionType)")
                
                devices.append(Device(
                    deviceId: deviceId,
                    deviceName: deviceName,
                    connectionType: connectionType
                ))
            }
        }
        
        print("解析到有效设备数量: \(devices.count)")
        
        // 对设备列表进行排序，物理设备(USB)优先于网络设备
        let sortedDevices = devices.sorted { (device1, device2) -> Bool in
            if device1.connectionType == "USB" && device2.connectionType != "USB" {
                return true
            } else if device1.connectionType != "USB" && device2.connectionType == "USB" {
                return false
            }
            return true
        }
        
        if devices.count != sortedDevices.count {
            print("警告: 排序后设备数量异常")
        }
        
        print("设备排序后顺序: \(sortedDevices.map { "\($0.deviceId) (\($0.connectionType))" })")
        return sortedDevices
    }
    
    /// 检查字符串是否为有效的IP地址格式
    private func isValidIPAddressFormat(_ string: String) -> Bool {
        // 检查是否包含IP地址常见字符
        if !string.contains(".") && !string.contains(":") {
            return false
        }
        
        // IP地址部分应包含数字
        if string.rangeOfCharacter(from: CharacterSet.decimalDigits) == nil {
            return false
        }
        
        // 典型的格式检查
        // 1. IP:PORT格式 (如 127.0.0.1:5555)
        let ipPortPattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+$"#
        
        // 2. 主机名:端口格式 (如 localhost:5555)
        let hostnamePortPattern = #"^[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)*:\d+$"#
        
        if let ipPortRegex = try? NSRegularExpression(pattern: ipPortPattern),
           ipPortRegex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil {
            return true
        }
        
        if let hostnamePortRegex = try? NSRegularExpression(pattern: hostnamePortPattern),
           hostnamePortRegex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil {
            return true
        }
        
        return false
    }
    
    // 查找目录中的HAP文件
    private func findHapFile(in directory: String) -> String? {
        let fileManager = FileManager.default
        do {
            // 先检查是否直接是HAP文件
            if directory.lowercased().hasSuffix(".hap") && fileManager.fileExists(atPath: directory) {
                return directory
            }
            
            // 如果是Zip文件，先解压
            let fileType = runCommandWithOutput("/usr/bin/file", args: [directory])
            if fileType.contains("Zip archive") {
                // 创建解压目录
                let extractDir = NSTemporaryDirectory() + "HapExtract_" + UUID().uuidString
                try fileManager.createDirectory(atPath: extractDir, withIntermediateDirectories: true, attributes: nil)
                
                print("解压应用包到: \(extractDir)")
                let unzipResult = runCommandWithOutput("/usr/bin/unzip", args: ["-o", directory, "-d", extractDir])
                print("解压结果: \(unzipResult)")
                
                // 查找解压后的目录中的HAP文件
                if let hapFile = findHapInExtractedDir(extractDir) {
                    return hapFile
                }
            }
            
            // 如果是目录，遍历查找HAP文件
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: directory, isDirectory: &isDirectory) && isDirectory.boolValue {
                let files = try fileManager.contentsOfDirectory(atPath: directory)
                
                // 优先寻找entry-default.hap或signed.hap这类关键文件名
                let priorityFiles = files.filter { 
                    let lowercased = $0.lowercased()
                    return lowercased.hasSuffix(".hap") && 
                           (lowercased.contains("entry") || 
                            lowercased.contains("default") || 
                            lowercased.contains("signed"))
                }
                
                if !priorityFiles.isEmpty {
                    print("找到优先级HAP文件: \(priorityFiles[0])")
                    return directory + "/" + priorityFiles[0]
                }
                
                // 其次寻找任何.hap文件
                for file in files {
                    if file.lowercased().hasSuffix(".hap") {
                        print("找到HAP文件: \(file)")
                        return directory + "/" + file
                    }
                }
                
                // 递归检查子目录
                for file in files {
                    let fullPath = directory + "/" + file
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) && isDir.boolValue {
                        if let hapInSubdir = findHapFile(in: fullPath) {
                            return hapInSubdir
                        }
                    }
                }
            }
        } catch {
            print("查找HAP文件失败: \(error.localizedDescription)")
        }
        return nil
    }
    
    // 在解压后的目录中查找HAP文件
    private func findHapInExtractedDir(_ extractDir: String) -> String? {
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(atPath: extractDir)
            
            // 优先寻找entry-default.hap文件
            for file in files {
                if file.lowercased() == "entry-default.hap" {
                    print("在解压目录中找到entry-default.hap文件")
                    return extractDir + "/" + file
                }
            }
            
            // 其次寻找任何.hap文件
            for file in files {
                if file.lowercased().hasSuffix(".hap") {
                    print("在解压目录中找到HAP文件: \(file)")
                    return extractDir + "/" + file
                }
            }
            
            // 检查子目录
            for file in files {
                let fullPath = extractDir + "/" + file
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) && isDir.boolValue {
                    if let hapInSubdir = findHapInExtractedDir(fullPath) {
                        return hapInSubdir
                    }
                }
            }
        } catch {
            print("搜索解压目录失败: \(error.localizedDescription)")
        }
        return nil
    }
    
    // 从包路径提取包名
    private func extractBundleId(from packagePath: String) -> String {
        // 1. 首先尝试从HAP文件中提取真实的bundleName
        if packagePath.lowercased().hasSuffix(".hap") && FileManager.default.fileExists(atPath: packagePath) {
            let tempDir = NSTemporaryDirectory() + "hap_extract_" + UUID().uuidString
            
            // 创建临时目录
            do {
                try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: nil)
                
                // 解压module.json文件
                let unzipProcess = Process()
                unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzipProcess.arguments = ["-o", packagePath, "module.json", "-d", tempDir]
                
                let outputPipe = Pipe()
                unzipProcess.standardOutput = outputPipe
                
                try unzipProcess.run()
                unzipProcess.waitUntilExit()
                
                // 读取module.json文件内容
                let moduleJsonPath = tempDir + "/module.json"
                if FileManager.default.fileExists(atPath: moduleJsonPath) {
                    let jsonData = try Data(contentsOf: URL(fileURLWithPath: moduleJsonPath))
                    if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let app = json["app"] as? [String: Any],
                       let bundleName = app["bundleName"] as? String {
                        // 清理临时目录
                        try? FileManager.default.removeItem(atPath: tempDir)
                        return bundleName
                    }
                }
                
                // 清理临时目录
                try? FileManager.default.removeItem(atPath: tempDir)
            } catch {
                print("Error extracting bundleName: \(error)")
            }
        }
        
        // 2. 备选方法：如果无法提取到真实bundleName，退回到猜测方法
        let pathComponents = packagePath.split(separator: "/")
        
        // 尝试从文件名猜测包名
        for component in pathComponents.reversed() {
            let filename = String(component)
            if filename.lowercased().contains("entry") || filename.lowercased().hasSuffix(".hap") {
                // 如果文件名中包含entry或以.hap结尾，尝试构造包名
                if let range = filename.range(of: "-") {
                    let prefix = filename[..<range.lowerBound]
                    return "com.\(prefix).harmonyapp"
                }
            }
        }
        
        // 默认包名
        return "com.example.harmonyapp"
    }
    
    // 执行命令并获取输出
    private func runCommandWithOutput(_ cmd: String, args: [String]) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.executableURL = URL(fileURLWithPath: cmd)
        task.arguments = args
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            task.waitUntilExit()
            return output
        } catch {
            print("执行命令失败: \(error.localizedDescription)")
            return "Error: \(error.localizedDescription)"
        }
    }
} 
