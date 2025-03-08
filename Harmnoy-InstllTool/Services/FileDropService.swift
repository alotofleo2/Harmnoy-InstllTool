import SwiftUI
import UniformTypeIdentifiers

struct FileDropService {
    static let supportedTypes = [
        UTType.package,
        UTType.archive,
        UTType.item,
        UTType(filenameExtension: "hap")!
    ]
    
    /// 检查文件是否为有效的HarmonyOS包
    static func isValidHarmonyPackage(_ url: URL) -> Bool {
        // 检查文件扩展名是否为.hap
        let fileExtension = url.pathExtension.lowercased()
        return fileExtension == "hap"
    }
}

struct FileDropDelegate: DropDelegate {
    let onDrop: (URL) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: FileDropService.supportedTypes)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: FileDropService.supportedTypes).first else {
            return false
        }
        
        itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard error == nil else {
                print("文件加载错误: \(error!)")
                return
            }
            
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                print("无法获取文件URL")
                return
            }
            
            // 检查是否为有效的HarmonyOS包
            if FileDropService.isValidHarmonyPackage(url) {
                DispatchQueue.main.async {
                    self.onDrop(url)
                }
                return
            } else {
                print("不是有效的HarmonyOS安装包")
                return
            }
        }
        
        return true
    }
} 