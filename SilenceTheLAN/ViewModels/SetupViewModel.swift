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
    @Published var availableRules: [ACLRuleDTO] = []
    @Published var availableFirewallRules: [FirewallRuleDTO] = []
    @Published var selectedRuleIds: Set<String> = []
    @Published var usingFirewallRules: Bool = true  // Default to firewall rules (REST API)

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
        usingFirewallRules = false

        logger.info("loadRules: Configuring API with host=\(self.host), siteId=\(self.siteId)")
        api.configure(host: host, siteId: siteId)

        var firewallError: String?
        var aclError: String?
        var firewallCount = 0
        var aclCount = 0

        // Try Firewall Rules (REST API) first - this is where most user-created rules live
        do {
            logger.info("loadRules: Trying Firewall Rules API...")
            let allFirewallRules = try await api.listFirewallRules()
            firewallCount = allFirewallRules.count
            logger.info("loadRules: Received \(firewallCount) firewall rules")

            // Log all rule names
            for rule in allFirewallRules {
                logger.debug("loadRules: Firewall rule '\(rule.name)' (enabled: \(rule.enabled), action: \(rule.action))")
            }

            // Filter to "downtime" rules (case-insensitive)
            availableFirewallRules = allFirewallRules.filter { rule in
                rule.name.lowercased().hasPrefix("downtime")
            }

            if !availableFirewallRules.isEmpty {
                logger.info("loadRules: Found \(self.availableFirewallRules.count) 'downtime' firewall rules")
                usingFirewallRules = true
                isLoading = false
                return
            }

            logger.info("loadRules: No 'downtime' firewall rules found in \(firewallCount) total, trying ACL rules...")
        } catch {
            firewallError = error.localizedDescription
            logger.warning("loadRules: Firewall API failed: \(firewallError ?? "unknown"), trying ACL rules...")
        }

        // Fall back to ACL Rules (Integration API)
        do {
            logger.info("loadRules: Trying ACL Rules API...")
            let allRules = try await api.listACLRules()
            aclCount = allRules.count
            logger.info("loadRules: Received \(aclCount) ACL rules")

            for rule in allRules {
                logger.debug("loadRules: ACL rule '\(rule.name)' (enabled: \(rule.enabled), action: \(rule.action))")
            }

            availableRules = allRules.filter { rule in
                rule.name.lowercased().hasPrefix("downtime")
            }
            logger.info("loadRules: Found \(self.availableRules.count) 'downtime' ACL rules")

        } catch {
            aclError = error.localizedDescription
            logger.error("loadRules: ACL API also failed: \(aclError ?? "unknown")")
        }

        // Build detailed error message
        if availableRules.isEmpty && availableFirewallRules.isEmpty {
            var details: [String] = []
            if let fwErr = firewallError {
                details.append("Firewall API: \(fwErr)")
            } else {
                details.append("Firewall API: \(firewallCount) rules, 0 with 'downtime' prefix")
            }
            if let aclErr = aclError {
                details.append("ACL API: \(aclErr)")
            } else {
                details.append("ACL API: \(aclCount) rules, 0 with 'downtime' prefix")
            }
            errorMessage = details.joined(separator: "\n")
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
        if usingFirewallRules {
            selectedRuleIds = Set(availableFirewallRules.map { $0.id })
        } else {
            selectedRuleIds = Set(availableRules.map { $0.id })
        }
    }

    func deselectAllRules() {
        selectedRuleIds.removeAll()
    }

    func getSelectedRules() -> [ACLRuleDTO] {
        availableRules.filter { selectedRuleIds.contains($0.id) }
    }

    func getSelectedFirewallRules() -> [FirewallRuleDTO] {
        availableFirewallRules.filter { selectedRuleIds.contains($0.id) }
    }

    // Computed property for total available rules count
    var totalAvailableRulesCount: Int {
        usingFirewallRules ? availableFirewallRules.count : availableRules.count
    }

    var hasAvailableRules: Bool {
        usingFirewallRules ? !availableFirewallRules.isEmpty : !availableRules.isEmpty
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
