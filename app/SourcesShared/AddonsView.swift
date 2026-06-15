import SwiftUI

/// Add-ons installed on your account. Reads the Stremio account collection directly so synced
/// add-ons appear even if the local core profile has not caught up yet.
struct AddonsView: View {
    @EnvironmentObject private var account: StremioAccount
    @EnvironmentObject private var core: CoreBridge
    @EnvironmentObject private var theme: ThemeManager
    @State private var manifestURL = ""
    @State private var isInstalling = false
    @State private var installMessage: String?
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    Text("Add-ons").screenTitleStyle()
                    addAddonForm
                    if account.addons.isEmpty && core.addons.isEmpty {
                        hint(account.isSignedIn ? "No add-ons found yet." : "No local add-ons yet. Sign in to sync account add-ons.")
                    } else {
                        if !account.addons.isEmpty {
                            ForEach(account.addons) { addon in addonRow(addon) }
                        } else {
                            ForEach(core.addons) { addon in addonRow(addon) }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.screenInset)
                .padding(.vertical, Theme.Space.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.Palette.canvas.ignoresSafeArea())
            .task {
                if account.isSignedIn { await account.loadAddons() }
            }
            .sheet(isPresented: $showingAddSheet) {
                addAddonSheet
            }
        }
    }

    private var addAddonForm: some View {
        HStack(spacing: Theme.Space.md) {
            Button { showingAddSheet = true } label: {
                Label("Add add-on", systemImage: "plus.circle.fill")
            }
            .buttonStyle(ChipButtonStyle(selected: true))
            .disabled(isInstalling)

            if let installMessage {
                Text(installMessage)
                    .font(Theme.Typography.label)
                    .foregroundStyle(installMessage.hasPrefix("Added") ? Theme.Palette.accent : Theme.Palette.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: 980, alignment: .leading)
    }

    private var addAddonSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                Text("Add add-on")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)

                TextField("https://.../manifest.json", text: $manifestURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                    .font(Theme.Typography.body)
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.vertical, Theme.Space.sm)
                    .background(Theme.Palette.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    .disabled(isInstalling)

                HStack(spacing: Theme.Space.md) {
                    Button { installAddon("https://torrentio.strem.fun/manifest.json") } label: {
                        Label("Torrentio", systemImage: "bolt.horizontal.circle.fill")
                    }
                    .buttonStyle(ChipButtonStyle())
                    .disabled(isInstalling)

                    Button { installAddon() } label: {
                        Label(isInstalling ? "Adding" : "Add", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(ChipButtonStyle(selected: true))
                    .disabled(isInstalling || manifestURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Cancel") { showingAddSheet = false }
                        .buttonStyle(ChipButtonStyle())
                        .disabled(isInstalling)
                }

                if let installMessage {
                    Text(installMessage)
                        .font(Theme.Typography.label)
                        .foregroundStyle(installMessage.hasPrefix("Added") ? Theme.Palette.accent : Theme.Palette.danger)
                }

                Spacer()
            }
            .padding(Theme.Space.xxl)
            .frame(maxWidth: 980, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.Palette.canvas.ignoresSafeArea())
        }
    }

    private func addonRow(_ addon: AddonDescriptor) -> some View {
        Button {} label: {
            addonRowContent(
                name: addon.manifest.name,
                capabilities: addon.capabilities,
                host: addon.host,
                providesStreams: addon.providesStreams
            )
        }
        .buttonStyle(RowFocusStyle())
    }

    private func addonRowContent(name: String, capabilities: String, host: String, providesStreams: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            Image(systemName: providesStreams ? "play.rectangle.on.rectangle.fill" : "puzzlepiece.extension.fill")
                .font(.system(size: 36))
                .foregroundStyle(providesStreams ? Theme.Palette.accent : Theme.Palette.textTertiary)
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 8) {
                Text(name).font(Theme.Typography.cardTitle).foregroundStyle(Theme.Palette.textPrimary)
                Text(capabilities).font(Theme.Typography.label).foregroundStyle(Theme.Palette.textSecondary)
                Text(host).font(.system(size: 16, design: .monospaced)).foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: Theme.Space.sm)
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addonRow(_ addon: CoreDescriptor) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            Image(systemName: addon.providesStreams ? "play.rectangle.on.rectangle.fill" : "puzzlepiece.extension.fill")
                .font(.system(size: 36))
                .foregroundStyle(addon.providesStreams ? Theme.Palette.accent : Theme.Palette.textTertiary)
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 8) {
                Text(addon.manifest.name).font(Theme.Typography.cardTitle).foregroundStyle(Theme.Palette.textPrimary)
                Text(addon.capabilities).font(Theme.Typography.label).foregroundStyle(Theme.Palette.textSecondary)
                Text(addon.host).font(.system(size: 16, design: .monospaced)).foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: Theme.Space.sm)
            if !addon.isProtected {
                Button { core.uninstallAddon(addon) } label: { Label("Remove", systemImage: "trash") }
                    .buttonStyle(ChipButtonStyle(selected: true, accent: Theme.Palette.danger, accentText: Theme.Palette.danger))
                    .fixedSize()   // keep the Remove chip at its intrinsic width so a narrow phone row can't squeeze the label to one glyph per line
            }
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Palette.textSecondary)
            .frame(maxWidth: 820, alignment: .leading)
            .padding(.top, Theme.Space.sm)
    }

    private func installAddon(_ rawURL: String? = nil) {
        let url = rawURL ?? manifestURL
        isInstalling = true
        installMessage = nil
        Task {
            do {
                let addons = try await account.installAddon(manifestURL: url)
                if !account.isE2EMode { core.signedInWithLegacyAuthKey() }
                await account.loadAddons()
                let added = addons.first { $0.transportUrl.localizedCaseInsensitiveContains(url.trimmingCharacters(in: .whitespacesAndNewlines)) }
                installMessage = "Added \(added?.manifest.name ?? "add-on")."
                manifestURL = ""
                showingAddSheet = false
            } catch {
                installMessage = error.localizedDescription
            }
            isInstalling = false
        }
    }
}
