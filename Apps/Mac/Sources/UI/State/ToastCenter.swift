import SwiftUI
import Combine
import Theme

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(center: ToastCenter) {
        self.center = center
    }

    public var body: some View {
        Group {
            if let toast = center.current {
                HStack(alignment: .top, spacing: DesignTokens.Space.space3) {
                    Image(systemName: icon(for: toast.kind))
                        .tokenFont(.sectionTitle)
                        .foregroundStyle(tint(for: toast.kind))
                    VStack(alignment: .leading, spacing: DesignTokens.Space.space1) {
                        if let arg = toast.messageArg {
                            Text(LocalizedStringKey(stringLiteral: formatMessage(key: toast.messageKey, arg: arg)))
                        } else {
                            Text(toast.messageKey)
                        }
                    }
                    .tokenFont(.supporting)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: DesignTokens.Space.space2) {
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
                                .foregroundStyle(DesignTokens.Palette.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("common.close"))
                    }
                }
                .padding(DesignTokens.Space.space3)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                        .stroke(tint(for: toast.kind).opacity(0.35), lineWidth: 1)
                )
                .padding(.horizontal, DesignTokens.Space.space4)
                .padding(.top, DesignTokens.Space.space3)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(DesignTokens.animation(reduceMotion: reduceMotion), value: center.current?.id)
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
        case .info: return DesignTokens.Palette.accent
        case .success: return DesignTokens.Palette.success
        case .warning: return DesignTokens.Palette.warning
        case .error: return DesignTokens.Palette.danger
        }
    }
}
