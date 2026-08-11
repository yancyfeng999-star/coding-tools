import SwiftUI
import Combine

// MARK: - Toast
//
// 顶部 banner：网络错误 / Sparkle 错误 / 通用提示。
// 自动消失 + 可手动关闭 + 可挂「重试」回调。
//
// 用法：
//   let toast = Toast(kind: .error, messageKey: "toast.networkError", messageArg: error.localizedDescription)
//   toastCenter.show(toast, retry: { ... })
//
// SwiftUI 集成：在 RootView 用 .overlay(alignment: .top) 渲染 ToastView(toastCenter: ...)

public struct Toast: Identifiable, Equatable {
    public enum Kind: String, Hashable, Sendable {
        case info, success, warning, error
    }

    public let id: UUID = UUID()
    public let kind: Kind
    /// LocalizedStringKey（SwiftUI Text 直接渲染）
    public let messageKey: LocalizedStringKey
    /// 可选参数：messageKey 里的 %@
    public let messageArg: String?
    /// 重试回调（nil 时不显示「重试」按钮）
    /// 不参与 Equatable 比较。
    public let retry: (() -> Void)?

    public init(kind: Kind = .info, messageKey: LocalizedStringKey, messageArg: String? = nil, retry: (() -> Void)? = nil) {
        self.kind = kind
        self.messageKey = messageKey
        self.messageArg = messageArg
        self.retry = retry
    }

    public static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
public final class ToastCenter: ObservableObject {
    public static let shared = ToastCenter()

    @Published public private(set) var current: Toast?

    /// 显示 toast（同一时刻只显示一个；新 toast 覆盖旧 toast）
    public func show(_ toast: Toast, autoDismissAfter seconds: TimeInterval = 5) {
        current = toast
        // 自动消失
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if self?.current?.id == toast.id {
                self?.current = nil
            }
        }
    }

    public func dismiss() {
        current = nil
    }
}

// MARK: - View

public struct ToastView: View {
    @ObservedObject public var center: ToastCenter

    public init(center: ToastCenter) {
        self.center = center
    }

    public var body: some View {
        Group {
            if let toast = center.current {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon(for: toast.kind))
                        .font(.title3)
                        .foregroundStyle(tint(for: toast.kind))
                    VStack(alignment: .leading, spacing: 4) {
                        // LocalizedStringKey 渲染（带 %@ 参数）
                        if let arg = toast.messageArg {
                            Text(LocalizedStringKey(stringLiteral: formatMessage(key: toast.messageKey, arg: arg)))
                        } else {
                            Text(toast.messageKey)
                        }
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 6) {
                        if let retry = toast.retry {
                            Button {
                                retry()
                                center.dismiss()
                            } label: {
                                Text("toast.retry")
                            }
                            .controlSize(.small)
                        }
                        Button {
                            center.dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tint(for: toast.kind).opacity(0.4), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: center.current?.id)
    }

    private func icon(for kind: Toast.Kind) -> String {
        switch kind {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    /// 把 LocalizedStringKey + arg 拼成 "toast.networkError arg" 形式，
    /// 让 SwiftUI Text(LocalizedStringKey) 渲染带参数。
    private func formatMessage(key: LocalizedStringKey, arg: String) -> String {
        // LocalizedStringKey.description 返回 "key" 形式
        let keyString = "\(key)"
        return "\(keyString) \(arg)"
    }

    private func tint(for kind: Toast.Kind) -> Color {
        switch kind {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}
