//
//  Harmnoy_InstllToolApp.swift
//  Harmnoy-InstllTool
//
//  Created by 方焘 on 2023/3/8.
//

import SwiftUI

@main
struct Harmnoy_InstllToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 创建一个环境变量，用于观察和响应URL事件
    @State private var receivedURL: URL? = nil
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    // 当应用变为活动状态时，检查是否有URL需要处理
                    if let url = receivedURL {
                        // 处理URL
                        receivedURL = nil
                    }
                    
                    // 确保应用程序窗口位于前台
                    if let window = NSApplication.shared.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .frame(minWidth: 600, minHeight: 550)
        }
        .handlesExternalEvents(matching: ["FitnessInstaller"])
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            // 移除不需要的菜单项
            CommandGroup(replacing: .newItem) {}
        }
    }
}
