import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let showsDoneButton: Bool
    let previewUsername: String?
    @State private var showResetConfirmation = false
    @State private var showLogoutConfirmation = false

    private var loggedInUsername: String? {
        previewUsername ?? (try? KeychainService.shared.getCredentials().username)
    }

    private var unifiHost: String {
        appState.networkMonitor.configuredHost ?? "Not configured"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.theme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Connection Status Section
                        SettingsSection(title: "CONNECTION") {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "wifi.router",
                                    iconColor: Color.theme.success,
                                    title: "UniFi Controller",
                                    value: appState.networkMonitor.isReachable ? "Connected" : "Offline",
                                    valueColor: appState.networkMonitor.isReachable ? Color.theme.success : Color.theme.danger
                                )

                                Divider()
                                    .background(Color.theme.border)

                                SettingsRow(
                                    icon: "server.rack",
                                    iconColor: Color.theme.primary,
                                    title: "IP Address",
                                    value: unifiHost
                                )
                            }
                        }

                        // Account Section
                        SettingsSection(title: "ACCOUNT") {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "person.circle",
                                    iconColor: Color.theme.accent,
                                    title: "Logged in as",
                                    value: loggedInUsername ?? "Unknown"
                                )

                                Divider()
                                    .background(Color.theme.border)

                                Button {
                                    showLogoutConfirmation = true
                                } label: {
                                    SettingsRow(
                                        icon: "rectangle.portrait.and.arrow.right",
                                        iconColor: Color.theme.textSecondary,
                                        title: "Log Out"
                                    )
                                }
                            }
                        }

                        // Rules Section
                        SettingsSection(title: "RULES") {
                            VStack(spacing: 0) {
                                NavigationLink {
                                    ManageRulesView()
                                        .environmentObject(appState)
                                } label: {
                                    SettingsRow(
                                        icon: "list.bullet.rectangle",
                                        iconColor: Color.theme.success,
                                        title: "Manage Rules",
                                        value: "\(appState.rules.count)",
                                        showChevron: true
                                    )
                                }

                                Divider()
                                    .background(Color.theme.border)

                                NavigationLink {
                                    ManagePrefixesView()
                                        .environmentObject(appState)
                                } label: {
                                    SettingsRow(
                                        icon: "tag",
                                        iconColor: Color.theme.accent,
                                        title: "Rule Prefixes",
                                        value: "\(RulePrefixMatcher.shared.prefixes.count)",
                                        showChevron: true
                                    )
                                }
                            }
                        }

                        // App Section
                        SettingsSection(title: "APP") {
                            SettingsRow(
                                title: "Version",
                                value: AppVersion.displayString
                            )
                        }

                        // Danger Zone
                        SettingsSection(title: "DANGER ZONE") {
                            Button {
                                showResetConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.title3)
                                    Text("Reset App")
                                        .font(.body)
                                    Spacer()
                                }
                                .foregroundColor(Color.theme.danger)
                                .padding(16)
                            }
                        }

                        Spacer()
                            .frame(height: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(Color.theme.success)
                        .fontWeight(.semibold)
                    }
                }
            }
            .alert("Reset App?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    appState.resetConfiguration()
                    dismiss()
                }
            } message: {
                Text("This will remove all settings and you'll need to set up the app again.")
            }
            .alert("Log Out?", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    appState.logout()
                    dismiss()
                }
            } message: {
                Text("You'll need to enter your credentials again to use the app.")
            }
        }
    }
}

extension SettingsView {
    init(showsDoneButton: Bool = true, previewUsername: String? = nil) {
        self.showsDoneButton = showsDoneButton
        self.previewUsername = previewUsername
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundColor(Color.theme.textTertiary)
                .padding(.horizontal, 4)

            content
                .background(Color.theme.surface)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.theme.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    var icon: String? = nil
    var iconColor: Color = Color.theme.textSecondary
    let title: String
    var value: String? = nil
    var valueColor: Color = Color.theme.textSecondary
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 28)
            }

            Text(title)
                .font(.body)
                .foregroundColor(.white)

            Spacer()

            if let value = value {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(valueColor)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.theme.textTertiary)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
