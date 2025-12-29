import Foundation
import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.shrisha.SilenceTheLAN", category: "SetupViewModel")

@MainActor
final class SetupViewModel: ObservableObject {
    @Published var currentStep: SetupStep = .welcome
    @Published var host: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var siteId: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var discoveredHost: String?
    @Published var availableSites: [UniFiSite] = []
    @Published var availableFirewallRules: [FirewallPolicyDTO] = []
    @Published var selectedRuleIds: Set<String> = []

    enum SetupStep: CaseIterable {
        case welcome
        case discovery
        case credentials  // Username/password for LOCAL account
        case siteId
        case ruleSelection
        case complete
    }

    private let api = UniFiAPIService()

    // MARK: - Site Selection

    func selectSite(_ site: UniFiSite) {
        siteId = site.name  // REST API uses site name, not UUID
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

    // MARK: - Credentials Verification (Local Account Auth)

    func verifyCredentials() async -> Bool {
        guard !host.isEmpty, !username.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter host, username, and password"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            // Configure API with host
            api.configure(host: host, siteId: "default")

            // Try to login
            try await api.login(username: username, password: password)

            // Save credentials on success
            try KeychainService.shared.saveCredentials(username: username, password: password)

            // Fetch available sites after successful login
            let sites = try await api.listSitesViaREST()
            availableSites = sites

            // If only one site, auto-select it
            if sites.count == 1 {
                siteId = sites[0].name
            }

            logger.info("Login successful, found \(sites.count) sites")
            isLoading = false
            return true
        } catch UniFiAPIError.unauthorized {
            errorMessage = "Invalid username or password"
        } catch UniFiAPIError.twoFactorRequired {
            errorMessage = "2FA is enabled on this account. Please create a LOCAL admin account without 2FA for API access."
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
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
            try await api.ensureLoggedIn()
            let sites = try await api.listSitesViaREST()
            availableSites = sites

            if sites.count == 1 {
                siteId = sites[0].name
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
            logger.error("loadRules: Configuration incomplete - host=\(self.host), siteId=\(self.siteId)")
            errorMessage = "Configuration incomplete"
            return
        }

        isLoading = true
        errorMessage = nil

        logger.info("loadRules: Configuring API with host=\(self.host), siteId=\(self.siteId)")
        api.configure(host: host, siteId: siteId)

        do {
            logger.info("loadRules: Fetching firewall rules...")
            let allFirewallRules = try await api.listFirewallRules()
            logger.info("loadRules: Received \(allFirewallRules.count) firewall rules")

            // Log all rule names for debugging
            for rule in allFirewallRules {
                logger.debug("loadRules: Rule '\(rule.name)' (enabled: \(rule.enabled), action: \(rule.action))")
            }

            // Filter to rules matching configured prefixes with BLOCK action
            let matcher = RulePrefixMatcher.shared
            availableFirewallRules = matcher.filterBlockingRules(
                allFirewallRules,
                getName: { $0.name },
                getAction: { $0.action }
            )

            if availableFirewallRules.isEmpty {
                if allFirewallRules.isEmpty {
                    errorMessage = "No firewall rules found. Make sure you have firewall rules configured in UniFi."
                } else {
                    // Check if there are matching rules but they're not BLOCK rules
                    let matchingRules = allFirewallRules.filter { matcher.matches($0.name) }
                    let prefixList = matcher.prefixes.joined(separator: ", ")
                    if matchingRules.isEmpty {
                        errorMessage = "Found \(allFirewallRules.count) firewall rules, but none with configured prefixes (\(prefixList)).\n\nCreate rules starting with one of these prefixes (e.g., 'Downtime-Kids' or 'STL-Kids') that BLOCK traffic."
                    } else {
                        errorMessage = "Found \(matchingRules.count) matching rules, but none are BLOCK rules.\n\nMake sure your rules have action set to BLOCK."
                    }
                }
            } else {
                logger.info("loadRules: Found \(self.availableFirewallRules.count) matching BLOCK firewall rules")
            }
        } catch {
            logger.error("loadRules: Firewall API failed: \(error.localizedDescription)")
            errorMessage = "Failed to load rules: \(error.localizedDescription)"
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
        selectedRuleIds = Set(availableFirewallRules.map { $0.id })
    }

    func deselectAllRules() {
        selectedRuleIds.removeAll()
    }

    func getSelectedFirewallRules() -> [FirewallPolicyDTO] {
        availableFirewallRules.filter { selectedRuleIds.contains($0.id) }
    }

    // Computed property for total available rules count
    var totalAvailableRulesCount: Int {
        availableFirewallRules.count
    }

    var hasAvailableRules: Bool {
        !availableFirewallRules.isEmpty
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
