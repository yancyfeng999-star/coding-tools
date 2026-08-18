import SwiftUI
import Theme

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space5) {
            HStack {
                Text("help.title")
                    .tokenFont(.pageTitle)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignTokens.Palette.secondaryText)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(Text("common.close"))
            }

            VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
                Text("help.shortcuts.title")
                    .tokenFont(.sectionTitle)
                shortcut("help.shortcuts.settings", keys: "⌘,")
                shortcut("help.shortcuts.update", keys: "⌘U")
                shortcut("help.shortcuts.close", keys: "Esc")
                shortcut("help.shortcuts.default", keys: "↩")
            }

            VStack(alignment: .leading, spacing: DesignTokens.Space.space3) {
                Text("help.faq.title")
                    .tokenFont(.sectionTitle)
                faq("help.faq.install.q", "help.faq.install.a")
                faq("help.faq.update.q", "help.faq.update.a")
                faq("help.faq.sudo.q", "help.faq.sudo.a")
                faq("help.faq.privacy.q", "help.faq.privacy.a")
            }
            Spacer()
        }
        .padding(DesignTokens.Space.space6)
        .frame(minWidth: 520, minHeight: 420)
        .background(DesignTokens.Palette.appBackground)
    }

    private func shortcut(_ key: LocalizedStringKey, keys: String) -> some View {
        HStack {
            Text(key)
                .tokenFont(.body)
            Spacer()
            Text(keys)
                .tokenFont(.compactCode)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
        }
    }

    private func faq(_ question: LocalizedStringKey, _ answer: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.space1) {
            Text(question)
                .tokenFont(.itemTitle)
            Text(answer)
                .tokenFont(.supporting)
                .foregroundStyle(DesignTokens.Palette.secondaryText)
        }
    }
}
