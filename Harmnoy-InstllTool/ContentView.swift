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
                Text("拖入HarmonyOS安装包(.hap文件)")
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
                        Text("未检测到已连接的设备")
                            .foregroundColor(.gray)
                            .padding()
                        
                        if let error = hdcService.lastError, error.contains("未找到hdc工具") {
                            Button("选择hdc工具") {
                                showHdcPickerDialog = true
                            }
                            .buttonStyle(.borderedProminent)
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
                UTType(filenameExtension: "hap")!,
                .package,
                .archive,
                .data
            ],
            allowsMultipleSelection: false
        ) { result in
            print("文件选择对话框结果: \(result)")
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    print("选择的文件: \(url.path)")
                    // 开始安全访问文件
                    let accessGranted = url.startAccessingSecurityScopedResource()
                    print("文件访问权限状态: \(accessGranted ? "已授予" : "未授予")")
                    defer {
                        if accessGranted {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
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
        installPackagePath = url.path
        statusMessage = "已选择安装包: \(url.lastPathComponent)"
    }
    
    private func handleSelectedFile(_ url: URL) {
        print("处理选择的文件: \(url.path)")
        print("文件扩展名: \(url.pathExtension)")
        
        // 获取安全的文件路径访问
        let secureURL = url.startAccessingSecurityScopedResource() ? url : url
        defer {
            if url.startAccessingSecurityScopedResource() {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // 检查文件是否可访问
        let fileManager = FileManager.default
        if !fileManager.isReadableFile(atPath: secureURL.path) {
            print("文件无法读取: \(secureURL.path)")
            statusMessage = "文件无法读取，可能没有足够的权限"
            return
        }
        
        guard FileDropService.isValidHarmonyPackage(secureURL) else {
            print("文件不是有效的HarmonyOS安装包(.hap): \(secureURL.lastPathComponent)")
            statusMessage = "不是有效的HarmonyOS安装包(.hap)"
            return
        }
        
        print("文件有效，设置安装路径: \(secureURL.path)")
        installPackagePath = secureURL.path
        statusMessage = "已选择安装包: \(secureURL.lastPathComponent)"
    }
    
    private func installToDevice(_ deviceId: String) {
        guard let packagePath = installPackagePath else {
            statusMessage = "未选择安装包"
            return
        }
        
        isLoading = true
        statusMessage = "正在安装应用到设备..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try hdcService.installPackage(packagePath: packagePath, deviceId: deviceId)
                print("安装结果: \(result)")
                
                DispatchQueue.main.async {
                    isLoading = false
                    if result.contains("Success") {
                        statusMessage = "安装成功"
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
                    } else {
                        statusMessage = "安装失败: \(result)"
                    }
                }
            } catch {
                print("安装异常: \(error)")
                DispatchQueue.main.async {
                    isLoading = false
                    
                    // 检查特定错误类型
                    let errorString = error.localizedDescription
                    if errorString.contains("Not match target") || errorString.contains("check connect-key") {
                        // 处理连接密钥错误
                        statusMessage = "安装失败: 设备连接问题，请检查设备连接状态和开发者模式"
                    } else {
                        statusMessage = "安装失败: \(errorString)"
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
}

#Preview {
    ContentView()
}
