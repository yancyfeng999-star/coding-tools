import Foundation
import Installers

// MARK: - Helper main
//
// XPC Helper 进程入口（top-level code）。
// 启动顺序：
//   1. NSApplication 不需要（XPC service 是后台进程，没有 UI）
//   2. 立即起 NSXPCListener 监听 bundle id 的 Mach service
//   3. listener.resume() 之后 RunLoop 永不退出

let bundleID = Bundle.main.bundleIdentifier ?? "com.codingtools.helper"
HelperBootstrap.bootstrap(serviceName: bundleID)
