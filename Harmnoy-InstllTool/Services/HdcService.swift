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
        // 优先查找应用程序Resources目录下的hdc/hdc
        let appHdcPath = Bundle.main.bundlePath + "/Contents/Resources/hdc/hdc"
        if FileManager.default.fileExists(atPath: appHdcPath) {
            self.hdcBinaryPath = appHdcPath
            print("找到hdc工具: \(appHdcPath)")
            return
        }
        
        // 如果没有找到，尝试在开发时的路径列表中查找
        let possibleHdcPaths = [
            // 1. 开发目录下的ResourcesTools/hdc目录
            Bundle.main.bundlePath + "/../ResourcesTools/hdc/hdc",
            // 2. 开发目录下的ResourcesTools/toolchains/hdc
            Bundle.main.bundlePath + "/../ResourcesTools/toolchains/hdc",
            // 3. 检查系统路径
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
        
        print("警告: 未找到hdc工具。请确保将hdc工具放在ResourcesTools/hdc目录中")
        
        // 确保在主线程更新UI相关的@Published属性
        DispatchQueue.main.async { [weak self] in
            self?.lastError = "未找到hdc工具。请确保将hdc工具放在ResourcesTools/hdc目录中"
        }
    }
    
    /// 获取hdc工具所在目录
    private func getHdcDirectory() -> String? {
        guard let hdcPath = hdcBinaryPath else { return nil }
        return URL(fileURLWithPath: hdcPath).deletingLastPathComponent().path
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
            throw NSError(domain: "HdcService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "未找到hdc工具"])
        }
        
        // 检查安装包是否存在
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: packagePath) else {
            throw NSError(domain: "HdcService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "安装包文件不存在: \(packagePath)"])
        }
        
        print("原始文件路径: \(packagePath)")
        print("路径是否包含临时目录标记: \(packagePath.contains("/var/folders/") || packagePath.contains("/tmp/") ? "是" : "否")")
        print("文件读取权限: \(fileManager.isReadableFile(atPath: packagePath) ? "可读" : "不可读")")
        
        // 将文件复制到一个临时工作目录
        let baseWorkDir = NSTemporaryDirectory() + "harmony_install_\(UUID().uuidString)"
        let workDir = baseWorkDir + "/workspace"
        do {
            try fileManager.createDirectory(atPath: workDir, withIntermediateDirectories: true)
            print("创建工作目录: \(workDir)")
        } catch {
            print("创建工作目录失败: \(error)")
            throw NSError(domain: "HdcService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "无法创建工作目录: \(error.localizedDescription)"])
        }
        
        // 源文件路径和目标文件路径
        let url = URL(fileURLWithPath: packagePath)
        let fileName = url.lastPathComponent
        let destPath = workDir + "/" + fileName
        _ = URL(fileURLWithPath: destPath)
        
        // 复制源文件到工作目录
        do {
            // 总是使用命令行执行复制，确保权限被保留
            print("使用命令行复制文件到工作目录...")
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/cp")
            
            // 检查是否为目录
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: packagePath, isDirectory: &isDirectory)
            
            if isDirectory.boolValue {
                // 对于目录，使用-R参数递归复制
                task.arguments = ["-R", packagePath, destPath]
                print("源文件是目录，使用递归复制: cp -R \(packagePath) \(destPath)")
            } else {
                // 对于普通文件，不使用-R参数
                task.arguments = [packagePath, destPath]
                print("源文件是普通文件: cp \(packagePath) \(destPath)")
            }
            
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus != 0 {
                print("复制文件失败，退出状态码: \(task.terminationStatus)")
                throw NSError(domain: "HdcService", code: Int(task.terminationStatus),
                             userInfo: [NSLocalizedDescriptionKey: "复制文件到工作目录失败，命令退出状态码: \(task.terminationStatus)"])
            }
            
            print("复制命令完成，状态码: \(task.terminationStatus)")
            print("成功复制文件到工作目录: \(destPath)")
        } catch {
            print("复制文件到工作目录失败: \(error)")
            throw NSError(domain: "HdcService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "无法复制安装包到工作目录: \(error.localizedDescription)"])
        }
        
        // 确保文件可读
        guard fileManager.isReadableFile(atPath: destPath) else {
            print("复制后的文件不可读: \(destPath)")
            // 尝试修复权限
            do {
                print("尝试修复文件权限...")
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/chmod")
                task.arguments = ["-R", "755", destPath]
                try task.run()
                task.waitUntilExit()
                
                if !fileManager.isReadableFile(atPath: destPath) {
                    throw NSError(domain: "HdcService", code: -1,
                                 userInfo: [NSLocalizedDescriptionKey: "权限修复后仍无法读取文件: \(destPath)"])
                }
                print("权限修复成功")
            } catch {
                print("修复权限失败: \(error)")
                throw NSError(domain: "HdcService", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "复制后的安装包无法读取且无法修复权限: \(destPath)"])
            }
            return "" // 永远不会执行到这里，因为上面的 catch 块中会抛出异常
        }
        
        // 获取hdc工具所在目录
        let hdcDirectory = getHdcDirectory() ?? (URL(fileURLWithPath: hdcPath).deletingLastPathComponent().path)
        print("安装应用包：使用hdc目录 \(hdcDirectory)")
        print("复制后的安装包路径: \(destPath)")
        print("目标设备ID: \(deviceId)")
        
        // 检查文件详细信息
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: destPath, isDirectory: &isDirectory) {
            print("安装包类型: \(isDirectory.boolValue ? "目录" : "普通文件")")
        }
        
        // 查看目录内容（如果是目录）
        if isDirectory.boolValue {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: destPath)
                print("安装包内容文件数: \(contents.count)")
                if !contents.isEmpty {
                    print("部分内容: \(contents.prefix(5).joined(separator: ", "))")
                }
            } catch {
                print("无法查看安装包内容: \(error)")
            }
        }
        
        // 为安装操作创建脚本目录
        let scriptDir = baseWorkDir + "/scripts"
        do {
            try fileManager.createDirectory(atPath: scriptDir, withIntermediateDirectories: true)
        } catch {
            print("创建脚本目录失败: \(error)")
        }
        
        // 使用脚本方法执行安装命令
        let tempScriptPath = scriptDir + "/install_app.sh"
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
        echo "安装包路径: \(destPath)"
        
        # 直接显示文件详细信息
        echo "--- 文件信息 ---"
        ls -la "\(destPath)"
        echo "----------------"
        
        # 检查文件访问权限
        if [ ! -r "\(destPath)" ]; then
            echo "警告: 文件访问权限不足，尝试修复..."
            chmod -R a+rx "\(destPath)"
            if [ ! -r "\(destPath)" ]; then
                echo "错误: 修复权限失败，文件仍然无法读取"
                exit 1
            fi
            echo "已成功修复文件权限"
        fi
        
        # 检查文件类型
        echo "检查文件类型..."
        FILE_TYPE=$(file "\(destPath)")
        echo "文件类型结果: $FILE_TYPE"
        
        # 如果是ZIP文件且不是目录，先解压
        if [ ! -d "\(destPath)" ] && [[ "$FILE_TYPE" == *"Zip archive"* || "$FILE_TYPE" == *"archive data"* ]]; then
            echo "检测到ZIP格式文件，尝试解压..."
            EXTRACT_DIR="\(workDir)/extracted"
            mkdir -p "$EXTRACT_DIR"
            
            # 尝试使用unzip命令解压
            unzip -o "\(destPath)" -d "$EXTRACT_DIR" > /dev/null 2>&1
            UNZIP_RESULT=$?
            
            if [ $UNZIP_RESULT -eq 0 ]; then
                echo "解压成功，检查解压后的内容..."
                ls -la "$EXTRACT_DIR"
                
                # 检查是否有.hap文件
                HAP_FILES=$(find "$EXTRACT_DIR" -name "*.hap" -o -name "*.HAP")
                if [ ! -z "$HAP_FILES" ]; then
                    echo "在解压目录中找到.hap文件:"
                    echo "$HAP_FILES"
                    FIRST_HAP=$(echo "$HAP_FILES" | head -1)
                    echo "使用第一个.hap文件安装: $FIRST_HAP"
                    INSTALL_PATH="$FIRST_HAP"
                else
                    # 尝试找.app目录
                    APP_DIRS=$(find "$EXTRACT_DIR" -name "*.app" -type d)
                    if [ ! -z "$APP_DIRS" ]; then
                        echo "在解压目录中找到.app目录:"
                        echo "$APP_DIRS"
                        FIRST_APP=$(echo "$APP_DIRS" | head -1)
                        echo "使用第一个.app目录安装: $FIRST_APP"
                        INSTALL_PATH="$FIRST_APP"
                    else
                        echo "解压后没有找到.hap文件或.app目录，使用整个解压目录"
                        INSTALL_PATH="$EXTRACT_DIR"
                    fi
                fi
            else
                echo "解压失败，继续使用原始文件安装"
                INSTALL_PATH="\(destPath)"
            fi
        else
            # 对于目录或非ZIP文件，直接使用原始路径
            echo "使用原始文件路径安装"
            INSTALL_PATH="\(destPath)"
        fi
        
        # 检查安装包文件
        echo "检查安装包文件:"
        if [ -d "$INSTALL_PATH" ]; then
            echo "是目录，列出主要文件:"
            find "$INSTALL_PATH" -type f | head -10
            
            # 检查文件结构是否符合预期
            echo "检查是否为有效的应用包结构..."
            if [ -d "$INSTALL_PATH/AppEntry" ] || [ -d "$INSTALL_PATH/entry" ] || [ -d "$INSTALL_PATH/META-INF" ] || [ -d "$INSTALL_PATH/libs" ]; then
                echo "发现标准应用入口目录结构"
            else
                echo "警告: 未找到标准应用入口目录结构，列出目录内容:"
                ls -la "$INSTALL_PATH"
            fi
        else
            echo "是文件，文件信息:"
            ls -la "$INSTALL_PATH"
            echo "文件类型:"
            file "$INSTALL_PATH"
        fi
        
        # 确保文件有正确的访问权限
        echo "确保文件有正确的访问权限..."
        chmod -R a+rx "$INSTALL_PATH"
        
        # 尝试多种安装方式，从最可能成功的开始
        echo "----------------------------------------"
        echo "尝试安装方法 1: 标准安装命令"
        echo "运行: \(hdcPath) -t \(deviceId) install $INSTALL_PATH"
        "\(hdcPath)" -t "\(deviceId)" install "$INSTALL_PATH"
        RESULT=$?
        
        # 如果安装失败，尝试用不同的方式
        if [ $RESULT -ne 0 ] || grep -q "\\[Fail\\]" <<< "$(echo $("${hdcPath}" -t "${deviceId}" install "${INSTALL_PATH}" 2>&1))" || grep -q "Not any installation package was found" <<< "$(echo $("${hdcPath}" -t "${deviceId}" install "${INSTALL_PATH}" 2>&1))"; then
            echo "----------------------------------------"
            echo "首次安装尝试失败，尝试方法 2: app install命令"
            echo "运行: \(hdcPath) -t \(deviceId) app install $INSTALL_PATH"
            "\(hdcPath)" -t "\(deviceId)" app install "$INSTALL_PATH"
            RESULT=$?
            
            # 如果仍然失败，尝试使用绝对路径和其他选项
            if [ $RESULT -ne 0 ] || grep -q "\\[Fail\\]" <<< "$(echo $("${hdcPath}" -t "${deviceId}" app install "${INSTALL_PATH}" 2>&1))"; then
                echo "----------------------------------------"
                echo "方法 2失败，尝试方法 3: 使用相对路径"
                
                # 获取相对路径
                if [ -d "$INSTALL_PATH" ]; then
                    cd $(dirname "$INSTALL_PATH")
                    REL_PATH="./$(basename "$INSTALL_PATH")"
                else
                    cd $(dirname "$INSTALL_PATH")
                    REL_PATH="./$(basename "$INSTALL_PATH")"
                fi
                
                echo "当前目录已切换到: $(pwd)"
                echo "相对路径: $REL_PATH"
                
                echo "运行: \(hdcPath) -t \(deviceId) install $REL_PATH"
                "\(hdcPath)" -t "\(deviceId)" install "$REL_PATH"
                RESULT=$?
                
                # 如果仍然失败，尝试bm安装命令
                if [ $RESULT -ne 0 ] || grep -q "\\[Fail\\]" <<< "$(echo $("${hdcPath}" -t "${deviceId}" install "${REL_PATH}" 2>&1))"; then
                    echo "----------------------------------------"
                    echo "方法 3失败，尝试方法 4: 使用bm install命令"
                    echo "运行: \(hdcPath) -t \(deviceId) bm install -p $INSTALL_PATH"
                    "\(hdcPath)" -t "\(deviceId)" bm install -p "$INSTALL_PATH"
                    RESULT=$?
                    
                    # 如果所有方法都失败，尝试检查目录内的具体文件
                    if [ $RESULT -ne 0 ] || grep -q "\\[Fail\\]" <<< "$(echo $("${hdcPath}" -t "${deviceId}" bm install -p "${INSTALL_PATH}" 2>&1))"; then
                        echo "----------------------------------------"
                        echo "方法 4失败，尝试方法 5: 搜索.hap文件并安装"
                        HAP_FILES=$(find "$(dirname "$INSTALL_PATH")" -name "*.hap" -o -name "*.HAP")
                        if [ ! -z "$HAP_FILES" ]; then
                            echo "找到以下.hap文件:"
                            echo "$HAP_FILES"
                            
                            # 尝试安装找到的第一个.hap文件
                            FIRST_HAP=$(echo "$HAP_FILES" | head -1)
                            echo "尝试安装: $FIRST_HAP"
                            "\(hdcPath)" -t "\(deviceId)" install "$FIRST_HAP"
                            RESULT=$?
                            
                            if [ $RESULT -ne 0 ] || grep -q "\\[Fail\\]" <<< "$(echo $("${hdcPath}" -t "${deviceId}" install "${FIRST_HAP}" 2>&1))"; then
                                echo "尝试使用bm install命令安装hap文件"
                                "\(hdcPath)" -t "\(deviceId)" bm install -p "$FIRST_HAP"
                                RESULT=$?
                            fi
                        else
                            echo "未找到任何.hap文件"
                            
                            # 最后尝试使用jar命令检查是否为有效的HAP包
                            if [ -f "$INSTALL_PATH" ]; then
                                echo "尝试jar命令列出文件内容"
                                jar -tf "$INSTALL_PATH" || echo "jar命令失败，可能不是有效的HAP包"
                            fi
                        fi
                    fi
                fi
            fi
        fi
        
        echo "----------------------------------------"
        echo "安装过程结束，最终结果状态: $RESULT"
        if [ $RESULT -eq 0 ] && ! grep -q "\\[Fail\\]" <<< "$(echo $("${hdcPath}" -t "${deviceId}" install "${INSTALL_PATH}" 2>&1))" && ! grep -q "Not any installation package was found" <<< "$(echo $("${hdcPath}" -t "${deviceId}" install "${INSTALL_PATH}" 2>&1))"; then
            echo "安装成功完成"
        else
            echo "安装失败，状态码: $RESULT"
            exit 1
        fi
        
        exit $RESULT
        """
        
        try scriptContent.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptPath)
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [tempScriptPath]
        task.currentDirectoryURL = URL(fileURLWithPath: scriptDir)
        
        print("执行安装脚本: \(tempScriptPath)")
        try task.run()
        task.waitUntilExit()
        
        // 收集输出
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String
        if let str = String(data: data, encoding: .utf8) {
            output = str
            print("安装命令输出: \(output)")
        } else {
            output = "无法解析命令输出"
            print(output)
        }
        
        print("安装命令结果状态: \(task.terminationStatus)")
        
        // 清理临时资源
        do {
            try FileManager.default.removeItem(atPath: baseWorkDir)
            print("已清理临时工作目录")
        } catch {
            print("清理临时工作目录失败: \(error)")
        }
        
        // 判断安装结果，即使状态码为0，也要检查输出中是否包含错误信息
        if task.terminationStatus != 0 {
            throw NSError(domain: "HdcService", code: Int(task.terminationStatus),
                         userInfo: [NSLocalizedDescriptionKey: "命令执行失败: \(output)"])
        }
        
        // 检查输出中是否包含[Fail]或者特定错误信息
        if output.contains("[Fail]") || output.contains("Not any installation package was found") {
            // 即使状态码为0，如果包含明确的失败信息，也应视为失败
            print("检测到输出中包含失败信息，尽管状态码为0")
            throw NSError(domain: "HdcService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "安装失败: \(output.components(separatedBy: .newlines).first(where: { $0.contains("[Fail]") }) ?? "未找到有效的安装包")"])
        }
        
        return output
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
} 