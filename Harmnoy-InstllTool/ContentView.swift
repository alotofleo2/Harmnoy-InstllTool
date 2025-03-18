//
//  ContentView.swift
//  Harmnoy-InstllTool
//
//  Created by 方焘 on 2025/3/8.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var hdcService = HdcService()
    @State private var installPackagePath: String? = nil
    @State private var isLoading: Bool = false
    @State private var statusMessage: String = "准备就绪"
    @State private var showFilePickerDialog = false
    @State private var showHdcPickerDialog = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("HarmonyOS 安装工具")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 拖放区域
            VStack {
                Text("拖入HarmonyOS安装包(.app文件)")
                    .font(.headline)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(height: 150)
                        .foregroundColor(.gray)
                        .background(Color.red.opacity(0.05))
                    
                    if let path = installPackagePath {
                        VStack {
                            Image(systemName: "doc.fill")
                                .font(.largeTitle)
                            Text(path.components(separatedBy: "/").last ?? path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("点击选择新文件")
                                .font(.caption)
                        }
                    } else {
                        VStack {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.largeTitle)
                            Text("拖放文件到此处")
                                .padding(.bottom, 4)
                            Text("或点击选择文件")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .contentShape(Rectangle())
                .padding()
                .onDrop(of: FileDropService.supportedTypes, delegate: FileDropDelegate(onDrop: { url in
                    handleDroppedFile(url)
                }))
                .onTapGesture {
                    print("点击了文件上传区域")
                    showFilePickerDialog = true
                }
                .gesture(TapGesture().onEnded {
                    print("添加的手势被触发")
                    showFilePickerDialog = true
                })
            }
            
            // 设备列表
            VStack {
                HStack {
                    Text("已连接设备")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        hdcService.refreshDeviceList()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                if hdcService.connectedDevices.isEmpty {
                    VStack(spacing: 10) {
                        if let error = hdcService.lastError, error.contains("未检测到连接的设备") {
                            Text("未检测到已连接的设备")
                                .foregroundColor(.gray)
                                .padding(.vertical, 5)
                            Text("请确保您的HarmonyOS设备:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("• 已通过USB连接到电脑")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("• 已在设备上启用开发者选项")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("• 已在设备上授权USB调试")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("刷新设备列表") {
                                hdcService.refreshDeviceList()
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 5)
                        } else if let error = hdcService.lastError, error.contains("未找到hdc工具") {
                            Text("未检测到已连接的设备")
                                .foregroundColor(.gray)
                                .padding()
                            
                            Button("选择hdc工具") {
                                showHdcPickerDialog = true
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Text("未检测到已连接的设备")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                } else {
                    List {
                        ForEach(hdcService.connectedDevices) { device in
                            HStack {
                                Image(systemName: "display")
                                VStack(alignment: .leading) {
                                    Text(device.deviceName)
                                        .fontWeight(.medium)
                                    Text(device.deviceId)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("安装") {
                                    installToDevice(device.deviceId)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(installPackagePath == nil)
                            }
                        }
                    }
                    .frame(height: 150)
                }
            }
            .padding()
            
            // 状态区域
            VStack {
                if isLoading {
                    ProgressView()
                        .padding(.bottom, 5)
                }
                
                Text(statusMessage)
                    .foregroundColor(statusMessage.contains("失败") || statusMessage.contains("错误") ? .red : .primary)
            }
            .padding()
            
            Spacer()
            
            // 底部工具栏
            HStack {
                Spacer()
                
                if let error = hdcService.lastError, error.contains("未找到hdc工具") {
                    Button("选择hdc工具") {
                        showHdcPickerDialog = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 500, minHeight: 500)
        .onAppear {
            // 在应用启动时启动hdc服务并检测设备
            startServices()
        }
        .onChange(of: hdcService.lastError) { newError in
            if let error = newError {
                statusMessage = error
                
                if error.contains("未找到hdc工具") {
                    errorMessage = "未找到hdc工具。\n请确保已正确安装hdc工具，或手动选择hdc工具文件。"
                    showErrorAlert = true
                } else if error.contains("无法启动hdc服务") {
                    errorMessage = "无法启动hdc服务。\n可能是由于权限问题或hdc工具不兼容。"
                    showErrorAlert = true
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePickerDialog,
            allowedContentTypes: [
                UTType(filenameExtension: "app")!,
                UTType(filenameExtension: "hap")!
            ],
            allowsMultipleSelection: false
        ) { result in
            print("文件选择对话框结果: \(result)")
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    print("选择的文件: \(url.path)")
                    // 开始安全访问文件 - 不在defer块中释放，而是持续保持访问权限
                    let accessGranted = url.startAccessingSecurityScopedResource()
                    print("文件访问权限状态: \(accessGranted ? "已授予" : "未授予")")
                    
                    // 处理选择的文件
                    handleSelectedFile(url)
                } else {
                    print("未选择任何文件")
                }
            case .failure(let error):
                print("文件选择错误: \(error)")
                statusMessage = "选择文件失败: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showHdcPickerDialog,
            allowedContentTypes: [.unixExecutable, .executable],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // 复制选择的hdc工具到应用资源目录
                    copyHdcToolToResourcesDirectory(from: url)
                }
            case .failure(let error):
                statusMessage = "选择hdc工具失败: \(error.localizedDescription)"
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("hdc工具错误"),
                message: Text(errorMessage),
                primaryButton: .default(Text("选择hdc工具")) {
                    showHdcPickerDialog = true
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    private func startServices() {
        statusMessage = "正在启动hdc服务..."
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            hdcService.startHdcServer()
            
            DispatchQueue.main.async {
                if hdcService.lastError != nil {
                    statusMessage = hdcService.lastError!
                } else {
                    statusMessage = "hdc服务已启动,正在检测设备..."
                    hdcService.refreshDeviceList()
                    statusMessage = "准备就绪"
                }
                isLoading = false
            }
        }
    }
    
    private func handleDroppedFile(_ url: URL) {
        print("处理拖放文件: \(url.path), 类型: \(url.pathExtension)")
        
        // 获取安全的文件路径访问权限
        let isSecurityScopedResource = url.startAccessingSecurityScopedResource()
        print("文件安全访问权限状态: \(isSecurityScopedResource ? "已授予" : "未授予")")
        
        // 检查文件类型
        let fileExtension = url.pathExtension.lowercased()
        
        // 检查是否为支持的文件类型(.app或.hap)
        if fileExtension != "app" && fileExtension != "hap" {
            statusMessage = "错误: 只支持HarmonyOS安装包(.app或.hap)文件，不支持.\(url.pathExtension)文件"
            if isSecurityScopedResource {
                url.stopAccessingSecurityScopedResource()
            }
            return
        }
        
        // 确保文件可访问
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            statusMessage = "错误: 无法访问文件，权限不足"
            if isSecurityScopedResource {
                url.stopAccessingSecurityScopedResource()
            }
            return
        }
        
        // 验证是否为有效的HarmonyOS安装包
        guard FileDropService.isValidHarmonyPackage(url) else {
            statusMessage = "错误: 不是有效的HarmonyOS安装包(.app或.hap)"
            if isSecurityScopedResource {
                url.stopAccessingSecurityScopedResource()
            }
            return
        }
        
        // 存储文件路径和URL的映射关系，以便后续操作可以重新获取文件访问权限
        if isSecurityScopedResource {
            print("保持文件安全访问权限: \(url.path)")
            // 注意：我们故意不调用 url.stopAccessingSecurityScopedResource()
            // 以保持对文件的访问权限，直到应用不再需要访问
        }
        
        installPackagePath = url.path
        statusMessage = "已选择安装包: \(url.lastPathComponent)"
        print("设置安装路径为: \(url.path)")
    }
    
    private func handleSelectedFile(_ url: URL) {
        print("处理选择的文件: \(url.path), 类型: \(url.pathExtension)")
        
        // 获取安全的文件路径访问
        let accessGranted = url.startAccessingSecurityScopedResource()
        print("文件安全访问权限状态: \(accessGranted ? "已授予" : "未授予")")
        
        // 不管是否获得额外的安全访问权限，都尝试处理文件
        // 如果文件选择器返回的文件，通常应该已有基本的访问权限
        
        // 检查文件类型
        let fileExtension = url.pathExtension.lowercased()
        if fileExtension != "app" && fileExtension != "hap" {
            print("文件类型错误: 选择了.\(fileExtension)文件，但只支持.app和.hap文件")
            statusMessage = "错误: 只支持HarmonyOS安装包(.app或.hap)文件，不支持.\(fileExtension)文件"
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
            return
        }
        
        // 检查文件是否可访问
        let fileManager = FileManager.default
        if !fileManager.isReadableFile(atPath: url.path) {
            print("文件无法读取: \(url.path)")
            statusMessage = "错误: 文件无法读取，可能没有足够的权限"
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
            return
        }
        
        // 检查是否为有效的安装包
        guard FileDropService.isValidHarmonyPackage(url) else {
            print("文件不是有效的HarmonyOS安装包(.app或.hap): \(url.lastPathComponent)")
            statusMessage = "错误: 不是有效的HarmonyOS安装包(.app或.hap)"
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
            return
        }
        
        // 保持文件的安全访问权限，以便后续安装操作可以访问
        if accessGranted {
            print("保持文件安全访问权限: \(url.path)")
            // 注意：我们故意不调用 url.stopAccessingSecurityScopedResource()
            // 以保持对文件的访问权限，直到应用不再需要访问文件
        }
        
        print("文件有效，设置安装路径: \(url.path)")
        installPackagePath = url.path
        statusMessage = "已选择安装包: \(url.lastPathComponent)"
    }
    
    private func installToDevice(_ deviceId: String) {
        guard let packagePath = installPackagePath else {
            statusMessage = "未选择安装包"
            return
        }
        
        // 再次检查文件存在性
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: packagePath) else {
            print("错误: 安装包文件不存在或已被移动: \(packagePath)")
            statusMessage = "错误: 安装包文件不存在或已被移动"
            installPackagePath = nil
            return
        }
        
        // 检查文件扩展名
        let fileExtension = URL(fileURLWithPath: packagePath).pathExtension.lowercased()
        if fileExtension != "app" && fileExtension != "hap" {
            print("文件格式不正确: \(packagePath)")
            statusMessage = "错误: 只支持.app和.hap格式的HarmonyOS应用包"
            return
        }
        
        // 显示更详细的文件信息，这有助于诊断问题
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: packagePath, isDirectory: &isDirectory)
        print("安装文件详情:")
        print("- 路径: \(packagePath)")
        print("- 是否为目录: \(isDirectory.boolValue)")
        
        // 获取文件大小和属性
        if let attributes = try? fileManager.attributesOfItem(atPath: packagePath) {
            if let fileSize = attributes[.size] as? NSNumber {
                print("- 文件大小: \(fileSize.intValue) 字节")
            }
            if let fileType = attributes[.type] as? String {
                print("- 文件类型: \(fileType)")
            }
            if let creationDate = attributes[.creationDate] as? Date {
                print("- 创建时间: \(creationDate)")
            }
            if let permissions = attributes[.posixPermissions] as? NSNumber {
                print("- 文件权限: \(String(format: "0o%o", permissions.intValue))")
            }
        }
        
        print("- 文件可读: \(fileManager.isReadableFile(atPath: packagePath))")
        print("- 文件可写: \(fileManager.isWritableFile(atPath: packagePath))")
        
        // 检查文件类型
        var fileTypeDescription = "未知"
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        task.arguments = [packagePath]
        
        do {
            try task.run()
            task.waitUntilExit()
            if let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
                print("- 文件类型命令结果: \(output)")
                fileTypeDescription = output
            }
        } catch {
            print("无法获取文件类型: \(error)")
        }
        
        // 检查目录内容，如果是目录
        if isDirectory.boolValue {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: packagePath)
                print("- 目录内容数量: \(contents.count)")
                if !contents.isEmpty {
                    print("- 部分内容: \(contents.prefix(10).joined(separator: ", "))")
                }
            } catch {
                print("无法列出目录内容: \(error)")
            }
        }
        
        print("开始安装: 设备ID=\(deviceId), 安装包路径=\(packagePath)")
        isLoading = true
        statusMessage = "正在安装应用到设备，请稍候..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 执行安装操作
                let result = try hdcService.installPackage(packagePath: packagePath, deviceId: deviceId)
                print("安装结果: \(result)")
                
                DispatchQueue.main.async {
                    isLoading = false
                    
                    // 处理结果
                    if result.contains("Success") || result.contains("success") || result.contains("安装成功") {
                        statusMessage = "安装成功"
                        // 显示成功提示
                        let alert = NSAlert()
                        alert.messageText = "安装成功"
                        alert.informativeText = "应用程序已成功安装到设备"
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "确定")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            alert.runModal()
                        }
                    } else if result.contains("Not match target") || result.contains("check connect-key") {
                        // 处理连接密钥错误
                        statusMessage = "安装失败: 设备连接问题"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let alert = NSAlert()
                            alert.messageText = "设备连接错误"
                            alert.informativeText = """
                            无法连接到设备，可能原因:
                            1. 设备未处于开发者模式
                            2. 需要在设备上接受USB调试授权
                            3. 连接密钥不匹配
                            
                            请检查:
                            - 设备上是否有授权提示
                            - 重新插拔USB连接
                            - 确认设备已开启调试模式
                            """
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "确定")
                            alert.runModal()
                        }
                    } else if result.contains("Not any installation package was found") {
                        // 处理未找到安装包错误
                        statusMessage = "安装失败: 未找到有效的HarmonyOS安装包"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let alert = NSAlert()
                            alert.messageText = "安装包错误"
                            alert.informativeText = """
                            安装失败：系统无法识别此应用包。
                            
                            可能的原因:
                            1. 当前文件不是Harmony安装包，而是\(fileTypeDescription)
                            2. 应用包结构不完整或已损坏
                            3. 应用包内容不符合鸿蒙OS要求
                            
                            建议:
                            - 确认安装包来源可靠
                            - 检查安装包是否完整
                            - 尝试获取正确的.hap格式安装包而不是.app格式
                            """
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "确定")
                            alert.runModal()
                        }
                    } else if result.contains("方法 5失败") && result.contains("未找到任何.hap文件") {
                        // 特殊处理：未找到.hap文件的情况
                        statusMessage = "安装失败: 安装包中未找到有效的.hap文件"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let alert = NSAlert()
                            alert.messageText = "无效的安装包结构"
                            alert.informativeText = """
                            安装失败：在应用包中未找到任何有效的.hap文件。
                            
                            鸿蒙OS应用包内通常应该包含.hap文件，这是实际的应用程序安装单元。
                            当前文件是:\(fileTypeDescription)
                            
                            可能的原因:
                            1. 选择的.app包不是鸿蒙OS应用包，而是macOS应用包
                            2. 安装包结构不完整或已损坏
                            3. 安装包可能是特殊格式，不符合标准结构
                            
                            建议:
                            - 确认您选择的确实是鸿蒙OS安装包
                            - 从可靠来源重新获取安装包
                            - 尝试获取.hap格式的安装包而不是.app格式
                            """
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "确定")
                            alert.runModal()
                        }
                    } else {
                        // 处理其他错误，提取更有用的信息
                        var errorMsg = "安装失败"
                        var detailedInfo = "安装过程中发生错误。\n\n"
                        
                        // 尝试从结果中提取更有用的错误信息
                        if result.contains("Permission denied") || result.contains("权限不足") {
                            errorMsg += ": 权限不足"
                            detailedInfo += "错误类型: 权限错误\n"
                            detailedInfo += "可能原因: 应用无法访问文件或设备\n"
                        } else if result.contains("No such file") || result.contains("不存在") {
                            errorMsg += ": 文件不存在"
                            detailedInfo += "错误类型: 文件路径错误\n"
                            detailedInfo += "可能原因: 文件被移动或删除\n"
                        } else if result.contains("failed to copy") || result.contains("复制失败") {
                            errorMsg += ": 文件复制失败"
                            detailedInfo += "错误类型: 文件复制错误\n"
                            detailedInfo += "可能原因: 目标位置权限不足或磁盘空间不足\n"
                        } else if result.contains("broken pipe") || result.contains("连接中断") {
                            errorMsg += ": 设备连接中断"
                            detailedInfo += "错误类型: 连接错误\n"
                            detailedInfo += "可能原因: 设备被断开或重启\n"
                        } else if result.contains("[Fail]") {
                            let failLine = result.split(separator: "\n").first(where: { $0.contains("[Fail]") })?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "[Fail]未知错误"
                            errorMsg += ": " + failLine
                            detailedInfo += "错误类型: HarmonyOS设备报告的错误\n"
                            detailedInfo += "错误信息: \(failLine)\n"
                        } else {
                            // 如果没有特定错误信息，显示通用错误
                            errorMsg += ": " + (result.split(separator: "\n").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知错误")
                            detailedInfo += "无法确定具体原因，请检查日志以获取更多信息。\n"
                        }
                        
                        detailedInfo += "\n文件信息:\n"
                        detailedInfo += "- 路径: \(packagePath)\n"
                        detailedInfo += "- 类型: \(fileTypeDescription)\n"
                        
                        statusMessage = errorMsg
                        
                        // 显示通用错误对话框
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let alert = NSAlert()
                            alert.messageText = errorMsg
                            alert.informativeText = detailedInfo
                            alert.alertStyle = .critical
                            alert.addButton(withTitle: "确定")
                            alert.runModal()
                        }
                    }
                }
            } catch {
                print("安装异常: \(error)")
                
                // 提取错误详细信息
                let errorString = error.localizedDescription
                let nsError = error as NSError
                print("错误详情: 代码=\(nsError.code), 域=\(nsError.domain)")
                if let userInfo = nsError.userInfo as? [String: Any] {
                    for (key, value) in userInfo {
                        print("错误信息[\(key)]: \(value)")
                    }
                }
                
                DispatchQueue.main.async {
                    isLoading = false
                    
                    // 错误分类处理
                    let errorInfo: String
                    let alertTitle: String
                    
                    if errorString.contains("Not match target") || errorString.contains("check connect-key") {
                        statusMessage = "安装失败: 设备连接问题"
                        alertTitle = "设备连接错误"
                        errorInfo = """
                        无法连接到设备，可能原因:
                        1. 设备未处于开发者模式
                        2. 需要在设备上接受USB调试授权
                        3. 连接密钥不匹配
                        
                        请检查:
                        - 设备上是否有授权提示
                        - 重新插拔USB连接
                        - 确认设备已开启调试模式
                        """
                    } else if errorString.contains("Not any installation package was found") || errorString.contains("安装失败") {
                        statusMessage = "安装失败: 不支持的文件格式"
                        alertTitle = "安装包格式错误"
                        errorInfo = """
                        无法识别为有效的HarmonyOS安装包。
                        
                        文件类型: \(fileTypeDescription)
                        
                        可能的原因:
                        1. 文件格式不受支持
                        2. 安装包可能已损坏
                        3. 该文件可能不是HarmonyOS应用包
                        
                        建议:
                        - 尝试获取.hap格式的安装包
                        - 确认安装包来源可靠
                        """
                    } else if errorString.contains("无法读取") || errorString.contains("权限不足") {
                        statusMessage = "安装失败: 文件访问权限错误"
                        alertTitle = "文件访问错误"
                        errorInfo = """
                        无法访问安装包文件，权限不足。
                        
                        可能的原因:
                        1. 文件位于受保护的目录
                        2. 文件权限设置不正确
                        3. 磁盘访问权限问题
                        
                        建议:
                        - 将文件移动到桌面或文档文件夹
                        - 检查文件权限设置
                        """
                    } else if errorString.contains("文件不存在") {
                        statusMessage = "安装失败: 安装包文件不存在"
                        alertTitle = "文件不存在"
                        errorInfo = """
                        指定的安装包文件不存在或已被移动。
                        
                        路径: \(packagePath)
                        
                        请重新选择有效的安装包文件。
                        """
                    } else {
                        statusMessage = "安装失败: \(errorString)"
                        alertTitle = "安装失败"
                        errorInfo = """
                        安装过程中发生错误:
                        
                        \(errorString)
                        
                        错误代码: \(nsError.code)
                        文件类型: \(fileTypeDescription)
                        
                        请尝试使用正确格式的HarmonyOS安装包。
                        """
                    }
                    
                    let alert = NSAlert()
                    alert.messageText = alertTitle
                    alert.informativeText = errorInfo
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "确定")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        alert.runModal()
                    }
                }
            }
        }
    }
    
    private func copyHdcToolToResourcesDirectory(from url: URL) {
        statusMessage = "正在安装hdc工具..."
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                let resourcesDirectory = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
                let hdcDestinationPath = resourcesDirectory.appendingPathComponent("hdc")
                
                // 确保目标目录存在
                try fileManager.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
                
                // 如果目标路径已存在，先删除它
                if fileManager.fileExists(atPath: hdcDestinationPath.path) {
                    try fileManager.removeItem(at: hdcDestinationPath)
                }
                
                // 复制选择的文件到目标路径
                try fileManager.copyItem(at: url, to: hdcDestinationPath)
                
                // 设置执行权限
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hdcDestinationPath.path)
                
                DispatchQueue.main.async {
                    statusMessage = "hdc工具已安装，正在重新启动服务..."
                    isLoading = false
                    
                    // 重新启动服务
                    startServices()
                }
            } catch {
                DispatchQueue.main.async {
                    statusMessage = "安装hdc工具失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    // 选择安装包文件
    private func selectHarmonyPackage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.package, UTType(filenameExtension: "app")!, UTType(filenameExtension: "hap")!]
        panel.title = "选择HarmonyOS安装包"
        panel.message = "请选择HarmonyOS应用安装包(.app或.hap文件)"
        panel.prompt = "选择"
        
        print("正在打开文件选择面板...")
        let result = panel.runModal()
        
        if result == .OK, let selectedURL = panel.url {
            print("用户选择文件: \(selectedURL.path)")
            handleSelectedFile(selectedURL)
        } else {
            print("文件选择取消")
        }
    }
}

#Preview {
    ContentView()
}
