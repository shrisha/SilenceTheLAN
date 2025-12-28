import Foundation
import SwiftUI
import Combine

@MainActor
final class SetupViewModel: ObservableObject {
    @Published var currentStep: SetupStep = .welcome
    @Published var host: String = ""
    @Published var apiKey: String = ""
    @Published var siteId: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var discoveredHost: String?
    @Published var availableSites: [SiteDTO] = []
    @Published var availableRules: [ACLRuleDTO] = []
    @Published var selectedRuleIds: Set<String> = []

    enum SetupStep: CaseIterable {
        case welcome
        case discovery
        case apiKey
        case siteId
        case ruleSelection
        case complete
    }

    private let api = UniFiAPIService()

    // MARK: - Site Selection

    func selectSite(_ site: SiteDTO) {
        siteId = site.id
    }

    // MARK: - Network Discovery

    func discoverUniFi() async {
        isLoading = true
        errorMessage = nil

        // Get device's IP and try common gateway addresses
        let gatewayGuesses = getGatewayGuesses()

        for gateway in gatewayGuesses {
            if await testConnection(host: gateway) {
                discoveredHost = gateway
                host = gateway
                isLoading = false
                return
            }
        }

        isLoading = false
        // No auto-discovery, user will enter manually
    }

    private func getGatewayGuesses() -> [String] {
        // Common gateway patterns
        return [
            "192.168.1.1",
            "192.168.0.1",
            "10.0.0.1",
            "192.168.1.254",
            "192.168.0.254"
        ]
    }

    private func testConnection(host: String) async -> Bool {
        guard let url = URL(string: "https://\(host)") else { return false }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3

        let session = URLSession(
            configuration: config,
            delegate: SSLTrustDelegate(),
            delegateQueue: nil
        )

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            let (_, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                return (200...499).contains(httpResponse.statusCode)
            }
        } catch {
            // Connection failed
        }

        return false
    }

    // MARK: - API Key Verification

    func verifyAPIKey() async -> Bool {
        guard !host.isEmpty, !apiKey.isEmpty else {
            errorMessage = "Please enter host and API key"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            try KeychainService.shared.saveAPIKey(apiKey)

            // Try to fetch available sites
            let sites = try await api.listSites(host: host)
            availableSites = sites

            // If only one site, auto-select it
            if sites.count == 1 {
                siteId = sites[0].id
            }

            isLoading = false
            return true
        } catch UniFiAPIError.unauthorized {
            errorMessage = "Invalid API key"
            try? KeychainService.shared.deleteAPIKey()
        } catch {
            // Sites endpoint might not exist, continue anyway
            print("Sites fetch error (non-fatal): \(error)")
            isLoading = false
            return true
        }

        isLoading = false
        return false
    }

    // MARK: - Fetch Sites

    func fetchSites() async {
        guard !host.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let sites = try await api.listSites(host: host)
            availableSites = sites

            if sites.count == 1 {
                siteId = sites[0].id
            }
        } catch {
            print("Failed to fetch sites: \(error)")
            // Non-fatal - user can enter manually
        }

        isLoading = false
    }

    // MARK: - Load Rules

    func loadRules() async {
        guard !host.isEmpty, !siteId.isEmpty else {
            errorMessage = "Configuration incomplete"
            return
        }

        isLoading = true
        errorMessage = nil

        api.configure(host: host, siteId: siteId)

        do {
            let allRules = try await api.listACLRules()

            // Filter to "downtime" rules (case-insensitive)
            availableRules = allRules.filter { rule in
                rule.name.lowercased().hasPrefix("downtime")
            }

            if availableRules.isEmpty {
                errorMessage = "No rules found with 'downtime' prefix"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleRuleSelection(_ ruleId: String) {
        if selectedRuleIds.contains(ruleId) {
            selectedRuleIds.remove(ruleId)
        } else {
            selectedRuleIds.insert(ruleId)
        }
    }

    func selectAllRules() {
        selectedRuleIds = Set(availableRules.map { $0.id })
    }

    func deselectAllRules() {
        selectedRuleIds.removeAll()
    }

    func getSelectedRules() -> [ACLRuleDTO] {
        availableRules.filter { selectedRuleIds.contains($0.id) }
    }

    // MARK: - Navigation

    func nextStep() {
        guard let currentIndex = SetupStep.allCases.firstIndex(of: currentStep),
              currentIndex < SetupStep.allCases.count - 1 else { return }
        currentStep = SetupStep.allCases[currentIndex + 1]
    }

    func previousStep() {
        guard let currentIndex = SetupStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        currentStep = SetupStep.allCases[currentIndex - 1]
    }

    func goToStep(_ step: SetupStep) {
        currentStep = step
    }
}
