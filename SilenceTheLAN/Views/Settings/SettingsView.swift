import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirmation = false

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
                                    iconColor: Color.theme.neonGreen,
                                    title: "UniFi Controller",
                                    value: appState.networkMonitor.isReachable ? "Connected" : "Offline",
                                    valueColor: appState.networkMonitor.isReachable ? Color.theme.neonGreen : Color.theme.neonRed
                                )

                                Divider()
                                    .background(Color.theme.glassStroke)

                                SettingsRow(
                                    icon: "network",
                                    iconColor: Color.theme.neonBlue,
                                    title: "Network",
                                    value: appState.networkMonitor.isWiFi ? "WiFi" : "Other"
                                )
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
                                        iconColor: Color.theme.neonPurple,
                                        title: "Manage Rules",
                                        value: "\(appState.rules.count)",
                                        showChevron: true
                                    )
                                }

                                Divider()
                                    .background(Color.theme.glassStroke)

                                Button {
                                    Task {
                                        await appState.refreshRules()
                                    }
                                } label: {
                                    SettingsRow(
                                        icon: "arrow.clockwise",
                                        iconColor: Color.theme.neonGreen,
                                        title: "Refresh Rules",
                                        showChevron: false
                                    )
                                }
                                .disabled(appState.isLoading)
                            }
                        }

                        // App Section
                        SettingsSection(title: "APP") {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "info.circle",
                                    iconColor: Color.theme.textSecondary,
                                    title: "Version",
                                    value: "1.0.0"
                                )
                            }
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
                                .foregroundColor(Color.theme.neonRed)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.theme.neonGreen)
                    .fontWeight(.semibold)
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
        }
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
                        .stroke(Color.theme.glassStroke, lineWidth: 1)
                )
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    var iconColor: Color = Color.theme.textSecondary
    let title: String
    var value: String? = nil
    var valueColor: Color = Color.theme.textSecondary
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 28)

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
