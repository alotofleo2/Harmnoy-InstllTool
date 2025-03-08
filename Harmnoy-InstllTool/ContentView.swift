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
                    Text("未检测到已连接的设备")
                        .foregroundColor(.gray)
                        .padding()
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
                    .foregroundColor(statusMessage.contains("失败") ? .red : .primary)
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 500)
        .onAppear {
            // 在应用启动时启动hdc服务并检测设备
            startServices()
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
}

#Preview {
    ContentView()
}
