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
    @State private var showLibPickerDialog = false
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
                    
                    if let path = installPackagePath {
                        VStack {
                            Image(systemName: "doc.fill")
                                .font(.largeTitle)
                            Text(path.components(separatedBy: "/").last ?? path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("点击安装或拖入新文件")
                                .font(.caption)
                        }
                    } else {
                        VStack {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.largeTitle)
                            Text("拖放文件到此处")
                        }
                    }
                }
                .padding()
                .onDrop(of: FileDropService.supportedTypes, delegate: FileDropDelegate(onDrop: { url in
                    handleDroppedFile(url)
                }))
                .onTapGesture {
                    showFilePickerDialog = true
                }
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
                        
                        if let error = hdcService.lastError {
                            if error.contains("未找到hdc工具") {
                                Button("选择hdc工具") {
                                    showHdcPickerDialog = true
                                }
                                .buttonStyle(.borderedProminent)
                            } else if error.contains("libusb_shared.dylib") {
                                VStack(spacing: 5) {
                                    Text("缺少libusb_shared.dylib库文件")
                                        .foregroundColor(.red)
                                    Button("选择libusb_shared.dylib文件") {
                                        showLibPickerDialog = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
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
                
                if let error = hdcService.lastError {
                    if error.contains("未找到hdc工具") {
                        Button("选择hdc工具") {
                            showHdcPickerDialog = true
                        }
                        .buttonStyle(.borderedProminent)
                    } else if error.contains("libusb_shared.dylib") {
                        Button("选择libusb_shared.dylib文件") {
                            showLibPickerDialog = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
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
                } else if error.contains("libusb_shared.dylib") {
                    errorMessage = "缺少libusb_shared.dylib库文件。\nhdc工具需要此库文件才能正常工作。"
                    showErrorAlert = true
                } else if error.contains("无法启动hdc服务") {
                    errorMessage = "无法启动hdc服务。\n可能是由于缺少必要的依赖库或权限问题。"
                    showErrorAlert = true
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePickerDialog,
            allowedContentTypes: FileDropService.supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    handleSelectedFile(url)
                }
            case .failure(let error):
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
        .fileImporter(
            isPresented: $showLibPickerDialog,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // 复制选择的libusb_shared.dylib库到应用资源目录
                    copyLibUsbToResourcesDirectory(from: url)
                }
            case .failure(let error):
                statusMessage = "选择库文件失败: \(error.localizedDescription)"
            }
        }
        .alert(isPresented: $showErrorAlert) {
            if let error = hdcService.lastError {
                if error.contains("未找到hdc工具") {
                    return Alert(
                        title: Text("hdc工具错误"),
                        message: Text(errorMessage),
                        primaryButton: .default(Text("选择hdc工具")) {
                            showHdcPickerDialog = true
                        },
                        secondaryButton: .cancel(Text("取消"))
                    )
                } else if error.contains("libusb_shared.dylib") {
                    return Alert(
                        title: Text("缺少依赖库"),
                        message: Text(errorMessage),
                        primaryButton: .default(Text("选择libusb_shared.dylib")) {
                            showLibPickerDialog = true
                        },
                        secondaryButton: .cancel(Text("取消"))
                    )
                }
            }
            
            return Alert(
                title: Text("错误"),
                message: Text(errorMessage),
                dismissButton: .default(Text("确定"))
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
        guard FileDropService.isValidHarmonyPackage(url) else {
            statusMessage = "不是有效的HarmonyOS安装包(.hap)"
            return
        }
        
        installPackagePath = url.path
        statusMessage = "已选择安装包: \(url.lastPathComponent)"
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
                
                DispatchQueue.main.async {
                    isLoading = false
                    if result.contains("Success") {
                        statusMessage = "安装成功"
                    } else {
                        statusMessage = "安装失败: \(result)"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    statusMessage = "安装失败: \(error.localizedDescription)"
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
    
    private func copyLibUsbToResourcesDirectory(from url: URL) {
        statusMessage = "正在安装libusb_shared.dylib库..."
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                let resourcesDirectory = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
                let libDestinationPath = resourcesDirectory.appendingPathComponent("libusb_shared.dylib")
                
                // 确保目标目录存在
                try fileManager.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
                
                // 如果目标路径已存在，先删除它
                if fileManager.fileExists(atPath: libDestinationPath.path) {
                    try fileManager.removeItem(at: libDestinationPath)
                }
                
                // 复制选择的文件到目标路径
                try fileManager.copyItem(at: url, to: libDestinationPath)
                
                DispatchQueue.main.async {
                    statusMessage = "libusb_shared.dylib库已安装，正在重新启动服务..."
                    isLoading = false
                    
                    // 重新启动服务
                    startServices()
                }
            } catch {
                DispatchQueue.main.async {
                    statusMessage = "安装库文件失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
