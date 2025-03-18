import SwiftUI
import UniformTypeIdentifiers

struct FileDropService {
    static let supportedTypes = [
        UTType.package,
        UTType.archive,
        UTType.item,
        UTType(filenameExtension: "app")!,
        UTType(filenameExtension: "hap")!
    ]
    
    /// 检查文件是否为有效的HarmonyOS包
    static func isValidHarmonyPackage(_ url: URL) -> Bool {
        // 检查文件扩展名是否为.app或.hap
        let fileExtension = url.pathExtension.lowercased()
        
        // 接受.app和.hap文件
        if fileExtension == "app" || fileExtension == "hap" {
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            
            // 首先检查文件是否存在
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                print("错误: 文件不存在")
                return false
            }
            
            // 检查文件大小是否合理
            do {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? NSNumber {
                    // 检查文件是否太小 (小于10KB可能不是有效包)
                    if fileSize.intValue < 10 * 1024 {
                        print("警告: 文件太小，可能不是有效的HarmonyOS应用包: \(fileSize.intValue) 字节")
                    }
                }
                
                // 判断是目录还是文件
                if isDirectory.boolValue {
                    // 如果是目录，检查是否包含重要文件或目录
                    do {
                        let contents = try fileManager.contentsOfDirectory(atPath: url.path)
                        print("目录内容: \(contents)")
                        
                        // 检查是否包含常见的HarmonyOS应用目录结构
                        let hasAppEntry = contents.contains(where: { $0 == "AppEntry" || $0 == "entry" || $0 == "META-INF" || $0 == "libs" })
                        let hasHapFiles = contents.contains(where: { $0.lowercased().hasSuffix(".hap") })
                        
                        if !hasAppEntry && !hasHapFiles {
                            print("警告: 目录不包含明确的HarmonyOS应用结构，但仍允许尝试安装")
                        }
                    } catch {
                        print("无法读取目录内容: \(error)")
                    }
                } else {
                    // 如果是文件，检查文件特征
                    // 运行file命令检查文件类型
                    let task = Process()
                    let pipe = Pipe()
                    
                    task.standardOutput = pipe
                    task.standardError = pipe
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/file")
                    task.arguments = [url.path]
                    
                    do {
                        try task.run()
                        task.waitUntilExit()
                        
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        if let output = String(data: data, encoding: .utf8) {
                            print("文件类型检查结果: \(output)")
                            
                            // 检查是否为ZIP文件或其他归档文件
                            let isZipArchive = output.contains("Zip archive") || 
                                            output.contains("JAR archive") || 
                                            output.contains("archive data") ||
                                            output.contains("compressed data")
                            
                            if isZipArchive {
                                print("文件识别为归档文件，可能是HarmonyOS应用包")
                            } else {
                                print("警告: 文件不是标准归档文件，可能无法安装")
                            }
                        }
                    } catch {
                        print("无法执行文件类型检查: \(error)")
                    }
                }
                
                // 最后仍然返回true允许尝试安装，但已在日志中提供警告
                return true
            } catch {
                print("检查文件属性时出错: \(error)")
            }
            
            return true
        }
        
        print("不支持的文件类型: .\(fileExtension)，仅支持.app和.hap文件")
        return false
    }
}

struct FileDropDelegate: DropDelegate {
    let onDrop: (URL) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        let isValid = info.hasItemsConforming(to: FileDropService.supportedTypes)
        print("验证拖放: \(isValid ? "有效" : "无效")")
        return isValid
    }
    
    func performDrop(info: DropInfo) -> Bool {
        print("开始执行拖放处理...")
        
        guard let itemProvider = info.itemProviders(for: FileDropService.supportedTypes).first else {
            print("没有找到符合要求的文件类型")
            return false
        }
        
        print("支持的类型标识符: \(itemProvider.registeredTypeIdentifiers)")
        
        // 直接使用文件表示方法，这更可靠
        itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) { (tempURL, error) in
            if let error = error {
                print("文件表示加载错误: \(error)")
                return
            }
            
            guard let tempURL = tempURL else {
                print("无法获取临时文件URL")
                return
            }
            
            print("临时文件URL: \(tempURL.path)")
            print("文件是否存在: \(FileManager.default.fileExists(atPath: tempURL.path) ? "是" : "否")")
            print("文件是否可读: \(FileManager.default.isReadableFile(atPath: tempURL.path) ? "是" : "否")")
            
            // 创建永久副本，不依赖临时文件
            let fileManager = FileManager.default
            do {
                let appSupportDir = try fileManager.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true)
                
                let appDir = appSupportDir.appendingPathComponent("HarmonyInstallTool", isDirectory: true)
                try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
                
                // 使用UUID确保文件名唯一
                let uniqueFileName = UUID().uuidString + "-" + tempURL.lastPathComponent
                let destinationURL = appDir.appendingPathComponent(uniqueFileName)
                
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                
                print("开始复制文件: \(tempURL.path) 到 \(destinationURL.path)")
                
                // 对于目录使用shell命令复制
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: tempURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                    print("复制目录结构使用命令行...")
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/cp")
                    process.arguments = ["-R", tempURL.path, destinationURL.path]
                    try process.run()
                    process.waitUntilExit()
                    
                    if process.terminationStatus != 0 {
                        print("命令行复制失败，状态码: \(process.terminationStatus)")
                        throw NSError(domain: "FileDropDelegate", code: Int(process.terminationStatus),
                                    userInfo: [NSLocalizedDescriptionKey: "复制文件失败"])
                    }
                } else {
                    // 对于普通文件使用FileManager
                    try fileManager.copyItem(at: tempURL, to: destinationURL)
                }
                
                print("完成复制: \(destinationURL.path)")
                print("复制后文件存在: \(fileManager.fileExists(atPath: destinationURL.path) ? "是" : "否")")
                
                // 设置完全权限
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
                
                if FileDropService.isValidHarmonyPackage(destinationURL) {
                    print("永久副本验证为有效的HarmonyOS包，处理拖放操作")
                    DispatchQueue.main.async {
                        self.onDrop(destinationURL)
                    }
                } else {
                    print("永久副本不是有效的HarmonyOS安装包: \(destinationURL.lastPathComponent)")
                }
                
            } catch {
                print("创建永久副本失败: \(error)")
                
                // 如果无法创建永久副本，尝试直接使用临时文件
                // 但此时必须立即处理，因为临时文件可能很快被删除
                if FileManager.default.isReadableFile(atPath: tempURL.path) {
                    print("无法创建永久副本，直接使用临时文件: \(tempURL.path)")
                    if FileDropService.isValidHarmonyPackage(tempURL) {
                        DispatchQueue.main.async {
                            self.onDrop(tempURL)
                        }
                    }
                }
            }
        }
        
        return true
    }
}
