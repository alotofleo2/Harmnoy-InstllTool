import SwiftUI
import UniformTypeIdentifiers

struct FileDropService {
    static let supportedTypes = [
        UTType.package,
        UTType.archive,
        UTType.item,
        UTType(filenameExtension: "app")!
    ]
    
    /// 检查文件是否为有效的HarmonyOS包
    static func isValidHarmonyPackage(_ url: URL) -> Bool {
        // 检查文件扩展名是否为.hap
        let fileExtension = url.pathExtension.lowercased()
        return fileExtension == "app"
    }
}

struct FileDropDelegate: DropDelegate {
    let onDrop: (URL) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: FileDropService.supportedTypes)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: FileDropService.supportedTypes).first else {
            print("没有找到符合要求的文件类型")
            return false
        }
        
        // 使用loadFileRepresentation代替loadItem以获取更好的文件URL处理
        itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) { url, error in
            guard error == nil else {
                print("文件加载错误: \(error!)")
                return
            }
            
            guard let url = url else {
                print("无法获取文件URL")
                return
            }
            
            // 创建永久URL来确保文件访问权限
            let permanentURL = URL(fileURLWithPath: url.path)
            
            // 检查文件是否可读
            guard FileManager.default.isReadableFile(atPath: permanentURL.path) else {
                print("无法读取文件: 权限被拒绝")
                return
            }
            
            // 检查是否为有效的HarmonyOS包
            if FileDropService.isValidHarmonyPackage(permanentURL) {
                DispatchQueue.main.async {
                    self.onDrop(permanentURL)
                }
            } else {
                print("不是有效的HarmonyOS安装包: \(permanentURL.lastPathComponent)")
            }
        }
        
        return true
    }
} 
