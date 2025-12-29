import SwiftUI

struct ManagePrefixesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var newPrefix: String = ""
    @State private var showAddField: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    private var customPrefixes: [String] {
        appState.customPrefixes
    }

    private var canAddMore: Bool {
        customPrefixes.count < RulePrefixMatcher.maxCustomPrefixes
    }

    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Info card
                    infoCard

                    // Default prefixes section
                    SettingsSection(title: "DEFAULT PREFIXES") {
                        VStack(spacing: 0) {
                            ForEach(RulePrefixMatcher.defaultPrefixes, id: \.self) { prefix in
                                HStack(spacing: 14) {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(Color.theme.textTertiary)

                                    Text(prefix)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.white)

                                    Spacer()

                                    Text("Built-in")
                                        .font(.caption)
                                        .foregroundColor(Color.theme.textTertiary)
                                }
                                .padding(16)

                                if prefix != RulePrefixMatcher.defaultPrefixes.last {
                                    Divider()
                                        .background(Color.theme.glassStroke)
                                }
                            }
                        }
                    }

                    // Custom prefixes section
                    SettingsSection(title: "CUSTOM PREFIXES") {
                        VStack(spacing: 0) {
                            if customPrefixes.isEmpty && !showAddField {
                                HStack {
                                    Text("No custom prefixes")
                                        .font(.body)
                                        .foregroundColor(Color.theme.textTertiary)
                                    Spacer()
                                }
                                .padding(16)
                            }

                            ForEach(customPrefixes, id: \.self) { prefix in
                                HStack(spacing: 14) {
                                    Text(prefix)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.white)

                                    Spacer()

                                    Button {
                                        withAnimation {
                                            appState.removeCustomPrefix(prefix)
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(Color.theme.neonRed.opacity(0.8))
                                    }
                                }
                                .padding(16)

                                Divider()
                                    .background(Color.theme.glassStroke)
                            }

                            // Add new prefix field
                            if showAddField {
                                HStack(spacing: 14) {
                                    TextField("Prefix-", text: $newPrefix)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.white)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($isTextFieldFocused)
                                        .onSubmit {
                                            addPrefix()
                                        }

                                    Button {
                                        addPrefix()
                                    } label: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(Color.theme.neonGreen)
                                    }
                                    .disabled(newPrefix.trimmingCharacters(in: .whitespaces).isEmpty)

                                    Button {
                                        withAnimation {
                                            showAddField = false
                                            newPrefix = ""
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(Color.theme.textTertiary)
                                    }
                                }
                                .padding(16)

                                Divider()
                                    .background(Color.theme.glassStroke)
                            }

                            // Add button
                            if canAddMore && !showAddField {
                                Button {
                                    withAnimation {
                                        showAddField = true
                                        isTextFieldFocused = true
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(Color.theme.neonGreen)

                                        Text("Add Custom Prefix")
                                            .font(.body)
                                            .foregroundColor(Color.theme.neonGreen)

                                        Spacer()
                                    }
                                    .padding(16)
                                }
                            } else if !canAddMore && !showAddField {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(Color.theme.textTertiary)
                                    Text("Maximum 3 custom prefixes")
                                        .font(.caption)
                                        .foregroundColor(Color.theme.textTertiary)
                                    Spacer()
                                }
                                .padding(16)
                            }
                        }
                    }

                    Spacer()
                        .frame(height: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationTitle("Rule Prefixes")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color.theme.neonBlue)
                Text("How Prefixes Work")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text("The app manages firewall rules that start with these prefixes. For example, a rule named \"Downtime-Kids\" or \"STL-Gaming\" will be detected.")
                .font(.subheadline)
                .foregroundColor(Color.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.theme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.theme.glassStroke, lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func addPrefix() {
        let trimmed = newPrefix.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        withAnimation {
            appState.addCustomPrefix(trimmed)
            newPrefix = ""
            showAddField = false
        }
    }
}

#Preview {
    NavigationStack {
        ManagePrefixesView()
            .environmentObject(AppState())
    }
}
