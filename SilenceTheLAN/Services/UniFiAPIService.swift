import Foundation
import OSLog

private let logger = Logger(subsystem: "com.shrisha.SilenceTheLAN", category: "UniFiAPI")

// MARK: - API Response Types

struct SiteListResponse: Codable {
    let data: [SiteDTO]
}

struct SiteDTO: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let timezone: String?
}

struct ACLRuleListResponse: Codable {
    let offset: Int
    let limit: Int
    let count: Int
    let totalCount: Int
    let data: [ACLRuleDTO]
}

struct ACLRuleDTO: Codable {
    let type: String
    let id: String
    let enabled: Bool
    let name: String
    let description: String?
    let action: String
    let index: Int
    let sourceFilter: AnyCodable?
    let destinationFilter: AnyCodable?
    let protocolFilter: [String]?
    let enforcingDeviceFilter: AnyCodable?
    let metadata: ACLRuleMetadata?
}

struct ACLRuleMetadata: Codable {
    let origin: String?
}

// MARK: - Firewall Policy Types (v2 API - zone-based rules)

struct FirewallPolicyDTO: Codable, Identifiable {
    let id: String  // "_id" in JSON
    let name: String
    let enabled: Bool
    let action: String  // "BLOCK", "ALLOW"
    let index: Int?
    let description: String?
    let source: FirewallZoneFilter?
    let destination: FirewallZoneFilter?
    let schedule: FirewallSchedule?
    let icmpTypename: String?
    let ipSecMatching: String?
    let logging: Bool?
    let matchingTarget: String?
    let stateEstablished: Bool?
    let stateInvalid: Bool?
    let stateNew: Bool?
    let stateRelated: Bool?
    let predefined: Bool?
    let rulesetId: String?
    let connectionStateMatching: String?
    let createTime: String?
    let protocolMatchExcepted: Bool?
    let `protocol`: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, enabled, action, index, description
        case source, destination, schedule
        case icmpTypename = "icmp_typename"
        case ipSecMatching = "ip_sec_matching"
        case logging
        case matchingTarget = "matching_target"
        case stateEstablished = "state_established"
        case stateInvalid = "state_invalid"
        case stateNew = "state_new"
        case stateRelated = "state_related"
        case predefined
        case rulesetId = "ruleset_id"
        case connectionStateMatching = "connection_state_matching"
        case createTime = "create_time"
        case protocolMatchExcepted = "protocol_match_excepted"
        case `protocol`
    }
}

struct FirewallZoneFilter: Codable {
    let zoneIds: [String]?
    let matchingTarget: String?  // "ANY", "IP", etc.
    let networkId: String?
    let networkIds: [String]?
    let macAddress: String?
    let ipGroupId: String?
    let portGroupId: String?
    let matchOppositeNats: Bool?
    let clientMac: String?
    let clientMacs: [String]?

    enum CodingKeys: String, CodingKey {
        case zoneIds = "zone_ids"
        case matchingTarget = "matching_target"
        case networkId = "network_id"
        case networkIds = "network_ids"
        case macAddress = "mac_address"
        case ipGroupId = "ip_group_id"
        case portGroupId = "port_group_id"
        case matchOppositeNats = "match_opposite_nats"
        case clientMac = "client_mac"
        case clientMacs = "client_macs"
    }
}

struct FirewallSchedule: Codable {
    let mode: String?  // "ALWAYS", "CUSTOM"
    let timeRangeStart: String?
    let timeRangeEnd: String?
    let repeatOnDays: [String]?

    enum CodingKeys: String, CodingKey {
        case mode
        case timeRangeStart = "time_range_start"
        case timeRangeEnd = "time_range_end"
        case repeatOnDays = "repeat_on_days"
    }
}

// MARK: - Firewall Rule Types (Legacy REST API)

struct FirewallRuleListResponse: Codable {
    let data: [FirewallRuleDTO]
    let meta: RESTAPIMeta
}

struct RESTAPIMeta: Codable {
    let rc: String
    let msg: String?
}

struct FirewallRuleDTO: Codable, Identifiable {
    let id: String  // "_id" in JSON, mapped via CodingKeys
    let name: String
    let enabled: Bool
    let action: String  // "drop", "accept", "reject"
    let ruleIndex: Int?
    let rulesetId: String?  // "WAN_IN", "WAN_OUT", "LAN_IN", etc.
    let siteId: String?

    // Optional fields for update
    let srcFirewallGroupIds: [String]?
    let dstFirewallGroupIds: [String]?
    let srcAddress: String?
    let dstAddress: String?
    let srcNetworkconfId: String?
    let dstNetworkconfId: String?
    let srcNetworkconfType: String?
    let dstNetworkconfType: String?
    let `protocol`: String?
    let protocolMatchExcepted: Bool?
    let icmpTypename: String?
    let logging: Bool?
    let stateNew: Bool?
    let stateEstablished: Bool?
    let stateInvalid: Bool?
    let stateRelated: Bool?
    let ipsecMatchExcepted: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, enabled, action
        case ruleIndex = "rule_index"
        case rulesetId = "ruleset"
        case siteId = "site_id"
        case srcFirewallGroupIds = "src_firewallgroup_ids"
        case dstFirewallGroupIds = "dst_firewallgroup_ids"
        case srcAddress = "src_address"
        case dstAddress = "dst_address"
        case srcNetworkconfId = "src_networkconf_id"
        case dstNetworkconfId = "dst_networkconf_id"
        case srcNetworkconfType = "src_networkconf_type"
        case dstNetworkconfType = "dst_networkconf_type"
        case `protocol`
        case protocolMatchExcepted = "protocol_match_excepted"
        case icmpTypename = "icmp_typename"
        case logging
        case stateNew = "state_new"
        case stateEstablished = "state_established"
        case stateInvalid = "state_invalid"
        case stateRelated = "state_related"
        case ipsecMatchExcepted = "ipsec"
    }
}

struct FirewallRuleUpdateRequest: Codable {
    let name: String
    let enabled: Bool
    let action: String
    let ruleIndex: Int?
    let rulesetId: String?
    let srcFirewallGroupIds: [String]?
    let dstFirewallGroupIds: [String]?
    let srcAddress: String?
    let dstAddress: String?
    let srcNetworkconfId: String?
    let dstNetworkconfId: String?
    let srcNetworkconfType: String?
    let dstNetworkconfType: String?
    let `protocol`: String?
    let logging: Bool?

    enum CodingKeys: String, CodingKey {
        case name, enabled, action
        case ruleIndex = "rule_index"
        case rulesetId = "ruleset"
        case srcFirewallGroupIds = "src_firewallgroup_ids"
        case dstFirewallGroupIds = "dst_firewallgroup_ids"
        case srcAddress = "src_address"
        case dstAddress = "dst_address"
        case srcNetworkconfId = "src_networkconf_id"
        case dstNetworkconfId = "dst_networkconf_id"
        case srcNetworkconfType = "src_networkconf_type"
        case dstNetworkconfType = "dst_networkconf_type"
        case `protocol`, logging
    }
}

struct ACLRuleUpdateRequest: Codable {
    let type: String
    let enabled: Bool
    let name: String
    let action: String
    let index: Int
    let description: String?
    let sourceFilter: AnyCodable?
    let destinationFilter: AnyCodable?
    let protocolFilter: [String]?
    let enforcingDeviceFilter: AnyCodable?
}

// MARK: - AnyCodable for dynamic JSON

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unable to encode value"
                )
            )
        }
    }
}

// MARK: - REST API Site Types

struct RESTSiteListResponse: Codable {
    let data: [UniFiSite]
    let meta: RESTAPIMeta
}

struct UniFiSite: Codable, Identifiable {
    let id: String  // "_id" in JSON
    let name: String
    let desc: String?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, desc, role
    }
}

// MARK: - API Errors

enum UniFiAPIError: Error, LocalizedError {
    case invalidURL
    case noAPIKey
    case noCredentials
    case unauthorized
    case twoFactorRequired
    case badRequest(String)
    case notFound
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid UniFi controller URL"
        case .noAPIKey:
            return "API key not configured"
        case .noCredentials:
            return "Credentials not configured"
        case .unauthorized:
            return "Invalid credentials"
        case .twoFactorRequired:
            return "2FA required - please use a local account"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .notFound:
            return "Rule not found"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Login Response Types

struct LoginRequest: Codable {
    let username: String
    let password: String
    let token: String
    let rememberMe: Bool

    init(username: String, password: String) {
        self.username = username
        self.password = password
        self.token = ""  // Empty token for non-2FA login
        self.rememberMe = true
    }
}

struct LoginResponse: Codable {
    let unique_id: String?
    let username: String?
}

// MARK: - API Service

final class UniFiAPIService {
    private let session: URLSession
    private var host: String = ""
    private var baseURL: String = ""
    private var siteId: String = ""

    // Session-based auth state
    private var csrfToken: String?
    private var sessionCookies: [HTTPCookie] = []
    private var isLoggedIn: Bool = false

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        // Enable cookie storage for session auth
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        // Try HTTP/1.1 instead of HTTP/2 (might help with SSL issues)
        config.httpAdditionalHeaders = ["Connection": "keep-alive"]

        self.session = URLSession(
            configuration: config,
            delegate: SSLTrustDelegate(),
            delegateQueue: nil
        )
    }

    func configure(host: String, siteId: String) {
        self.host = host
        self.baseURL = "https://\(host)/proxy/network/integration/v1/sites/\(siteId)"
        self.siteId = siteId
        logger.info("API configured: host=\(host), siteId=\(siteId)")
    }

    // MARK: - Session Login

    /// Clear any existing session state (call when logout or session invalid)
    func clearSession() {
        isLoggedIn = false
        csrfToken = nil
        sessionCookies = []

        // Clear cookies for this host
        if let url = URL(string: "https://\(host)"),
           let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
                logger.debug("Cleared cookie: \(cookie.name)")
            }
            logger.info("Cleared \(cookies.count) existing cookies")
        }

        // Clear saved CSRF token
        try? KeychainService.shared.deleteCSRFToken()
    }

    /// Restore session from persisted storage (call on app launch)
    func restoreSession() {
        // Check if we have a valid TOKEN cookie and extract CSRF from it
        if let url = URL(string: "https://\(host)"),
           let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for cookie in cookies {
                if cookie.name == "TOKEN" {
                    // Extract CSRF token from JWT
                    if let extractedCsrf = extractCsrfFromJWT(cookie.value) {
                        csrfToken = extractedCsrf
                        logger.info("Extracted CSRF token from stored JWT: \(extractedCsrf.prefix(20))...")
                        // Save the correct CSRF token
                        try? KeychainService.shared.saveCSRFToken(extractedCsrf)
                    }
                    // Check if cookie is not expired
                    if let expiresDate = cookie.expiresDate, expiresDate > Date() {
                        isLoggedIn = true
                        logger.info("Found valid session cookie, expires: \(expiresDate)")
                        return
                    } else if cookie.expiresDate == nil {
                        // Session cookie (no expiry) - assume valid
                        isLoggedIn = true
                        logger.info("Found session cookie (no expiry)")
                        return
                    }
                }
            }
        }

        logger.info("No valid session found, will need to login")
    }

    /// Check if we have a potentially valid session (without making a network request)
    func hasSession() -> Bool {
        guard !host.isEmpty else { return false }

        if let url = URL(string: "https://\(host)"),
           let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            return cookies.contains { $0.name == "TOKEN" }
        }
        return false
    }

    /// Fetch initial CSRF token and cookies before login
    private func fetchInitialCSRF() async {
        // Try to get initial cookies/CSRF by hitting the main page
        let urlString = "https://\(host)/"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        logger.info("Fetching initial CSRF/cookies from: \(urlString)")

        do {
            let (_, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("Initial request status: \(httpResponse.statusCode)")

                // Extract CSRF token from headers
                if let csrf = httpResponse.value(forHTTPHeaderField: "X-CSRF-Token") {
                    csrfToken = csrf
                    logger.info("Got CSRF token from initial request header: \(csrf.prefix(20))...")
                }

                // Store any cookies
                if let headerFields = httpResponse.allHeaderFields as? [String: String],
                   let responseURL = httpResponse.url {
                    let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: responseURL)
                    for cookie in cookies {
                        HTTPCookieStorage.shared.setCookie(cookie)
                        logger.debug("Got cookie: \(cookie.name)")
                        if cookie.name == "TOKEN" {
                            // TOKEN is a JWT - extract csrfToken from payload
                            if let extractedCsrf = extractCsrfFromJWT(cookie.value) {
                                csrfToken = extractedCsrf
                                logger.info("Extracted CSRF token from JWT: \(extractedCsrf.prefix(20))...")
                            }
                        } else if cookie.name == "csrf_token" {
                            csrfToken = cookie.value
                            logger.info("Got CSRF token from cookie: \(cookie.name)")
                        }
                    }
                }
            }
        } catch {
            logger.warning("Failed to fetch initial CSRF: \(error.localizedDescription)")
            // Continue anyway - login might still work
        }
    }

    /// Simple test to see if we can reach the server at all
    func testServerReachability() async -> Bool {
        let urlString = "https://\(host)/"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                logger.info("Test reachability: status \(httpResponse.statusCode)")
                return true
            }
        } catch {
            logger.error("Test reachability failed: \(error.localizedDescription)")
        }
        return false
    }

    func login(username: String, password: String) async throws {
        // Clear any existing cookies before login - stale tokens cause 403
        if let url = URL(string: "https://\(host)"),
           let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
            logger.info("Cleared \(cookies.count) cookies before login")
        }

        // Reset session state
        isLoggedIn = false
        csrfToken = nil

        // First test if we can reach the server at all
        let reachable = await testServerReachability()
        logger.info("Server reachability test: \(reachable)")

        let urlString = "https://\(host)/api/auth/login"
        guard let url = URL(string: urlString) else {
            throw UniFiAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Match exactly what curl sends (which works)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("https://\(host)", forHTTPHeaderField: "Origin")
        // Set User-Agent to match curl (iOS might add its own otherwise)
        request.setValue("curl/8.7.1", forHTTPHeaderField: "User-Agent")

        // Debug: Compare JSONEncoder output vs manual string
        let loginData = LoginRequest(username: username, password: password)
        let encoder = JSONEncoder()
        if let encodedData = try? encoder.encode(loginData),
           let encodedString = String(data: encodedData, encoding: .utf8) {
            logger.info("JSONEncoder output: \(encodedString)")
        }

        // Manual JSON (this works)
        let jsonString = "{\"username\":\"\(username)\",\"password\":\"\(password)\",\"token\":\"\",\"rememberMe\":true}"
        logger.info("Manual JSON: \(jsonString)")

        // Use manual JSON for now (known to work)
        request.httpBody = jsonString.data(using: .utf8)

        // Log request body for debugging
        if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            logger.info("Login request body: \(bodyString)")
            logger.debug("Login request body bytes: \(bodyData.count)")
        }

        // Log all request headers
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                logger.debug("Request header: \(key): \(value)")
            }
        }

        // Log cookies being sent
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            logger.info("Cookies being sent: \(cookies.count)")
            for cookie in cookies {
                logger.debug("Cookie: \(cookie.name)=\(cookie.value.prefix(20))...")
            }
        }

        logger.info("Attempting session login to: \(urlString)")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("Login network error: \(error.localizedDescription)")
            throw UniFiAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UniFiAPIError.networkError(NSError(domain: "UniFiAPI", code: -1))
        }

        logger.info("Login response status: \(httpResponse.statusCode)")

        // Log response body for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            logger.debug("Login response: \(responseString.prefix(200))")
        }

        switch httpResponse.statusCode {
        case 200...299:
            // Extract CSRF token from response headers
            if let csrf = httpResponse.value(forHTTPHeaderField: "X-CSRF-Token") {
                csrfToken = csrf
                logger.info("Got CSRF token from header")
            }

            // Store cookies
            if let headerFields = httpResponse.allHeaderFields as? [String: String],
               let responseURL = httpResponse.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: responseURL)
                sessionCookies = cookies
                for cookie in cookies {
                    HTTPCookieStorage.shared.setCookie(cookie)
                    if cookie.name == "TOKEN" {
                        // TOKEN is a JWT - extract csrfToken from payload
                        if let extractedCsrf = extractCsrfFromJWT(cookie.value) {
                            csrfToken = extractedCsrf
                            logger.info("Extracted CSRF token from JWT: \(extractedCsrf.prefix(20))...")
                        }
                    }
                }
                logger.info("Stored \(cookies.count) session cookies")
            }

            isLoggedIn = true
            logger.info("Session login successful")

            // Persist CSRF token for session restoration
            if let csrf = csrfToken {
                try? KeychainService.shared.saveCSRFToken(csrf)
                logger.info("Saved CSRF token to Keychain")
            }

        case 401:
            throw UniFiAPIError.unauthorized

        case 403:
            // Forbidden - could be wrong credentials, account not enabled, or account permissions
            let responseString = String(data: data, encoding: .utf8) ?? ""
            logger.error("Login forbidden (403): \(responseString)")

            // Check if response indicates specific issue
            if responseString.contains("2fa") || responseString.contains("mfa") {
                throw UniFiAPIError.twoFactorRequired
            }

            // 403 often means wrong username/password on UniFi
            throw UniFiAPIError.unauthorized

        case 499:
            // 2FA required - check response for confirmation
            logger.error("2FA required (status 499)")
            throw UniFiAPIError.twoFactorRequired

        default:
            // Check if response indicates 2FA requirement
            if let responseString = String(data: data, encoding: .utf8),
               responseString.contains("\"required\":\"2fa\"") {
                logger.error("2FA required (detected in response)")
                throw UniFiAPIError.twoFactorRequired
            }
            throw UniFiAPIError.serverError(httpResponse.statusCode)
        }
    }

    func ensureLoggedIn() async throws {
        // Already logged in this session
        if isLoggedIn {
            logger.debug("ensureLoggedIn: Already logged in")
            return
        }

        // Try to restore session from persisted storage
        restoreSession()
        if isLoggedIn {
            logger.info("ensureLoggedIn: Session restored from storage")
            return
        }

        // No valid session, need to login with credentials
        guard let credentials = try? KeychainService.shared.getCredentials() else {
            logger.warning("No credentials stored, cannot login")
            throw UniFiAPIError.noCredentials
        }

        logger.info("ensureLoggedIn: Logging in with stored credentials")
        try await login(username: credentials.username, password: credentials.password)
    }

    // MARK: - List Sites via REST API (session auth)

    func listSitesViaREST() async throws -> [UniFiSite] {
        let urlString = "https://\(host)/proxy/network/api/self/sites"
        guard let url = URL(string: urlString) else {
            throw UniFiAPIError.invalidURL
        }

        let request = buildSessionRequest(url: url, method: "GET")
        logger.info("Fetching sites via REST API: \(urlString)")

        let response: RESTSiteListResponse = try await execute(request)
        logger.info("Found \(response.data.count) sites via REST API")
        return response.data
    }

    // MARK: - List Sites (Integration API - for discovery)

    func listSites(host: String) async throws -> [SiteDTO] {
        let urlString = "https://\(host)/proxy/network/integration/v1/sites"
        guard let url = URL(string: urlString) else {
            throw UniFiAPIError.invalidURL
        }

        let request = try buildRequest(url: url, method: "GET")
        logger.info("Fetching sites from: \(urlString)")

        let response: SiteListResponse = try await execute(request)
        logger.info("Found \(response.data.count) sites")
        return response.data
    }

    // MARK: - List ACL Rules

    func listACLRules(limit: Int = 200) async throws -> [ACLRuleDTO] {
        let url = try buildURL(path: "/acl-rules", query: ["limit": "\(limit)"])
        let request = try buildRequest(url: url, method: "GET")

        logger.info("Fetching ACL rules from: \(url.absoluteString)")
        let response: ACLRuleListResponse = try await execute(request)
        logger.info("Found \(response.data.count) ACL rules (total: \(response.totalCount))")
        return response.data
    }

    // MARK: - Get Single ACL Rule

    func getACLRule(ruleId: String) async throws -> ACLRuleDTO {
        let url = try buildURL(path: "/acl-rules/\(ruleId)")
        let request = try buildRequest(url: url, method: "GET")

        return try await execute(request)
    }

    // MARK: - Update ACL Rule

    func updateACLRule(ruleId: String, update: ACLRuleUpdateRequest) async throws -> ACLRuleDTO {
        let url = try buildURL(path: "/acl-rules/\(ruleId)")
        var request = try buildRequest(url: url, method: "PUT")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(update)

        return try await execute(request)
    }

    // MARK: - Toggle Rule (Convenience)

    func toggleRule(ruleId: String, enabled: Bool) async throws -> ACLRuleDTO {
        // GET current state
        let current = try await getACLRule(ruleId: ruleId)

        // Build update with all required fields
        let update = ACLRuleUpdateRequest(
            type: current.type,
            enabled: enabled,
            name: current.name,
            action: current.action,
            index: current.index,
            description: current.description,
            sourceFilter: current.sourceFilter,
            destinationFilter: current.destinationFilter,
            protocolFilter: current.protocolFilter,
            enforcingDeviceFilter: current.enforcingDeviceFilter
        )

        // PUT updated rule
        return try await updateACLRule(ruleId: ruleId, update: update)
    }

    // MARK: - List Firewall Rules (REST API with session auth)

    func listFirewallRules() async throws -> [FirewallPolicyDTO] {
        // Use the configured siteId (which is the site name for REST API)
        let siteName = siteId.isEmpty ? "default" : siteId

        logger.info("listFirewallRules: Using site '\(siteName)', isLoggedIn=\(self.isLoggedIn)")

        // Ensure we're logged in
        try await ensureLoggedIn()

        logger.info("listFirewallRules: After ensureLoggedIn, isLoggedIn=\(self.isLoggedIn)")

        // v2 API endpoint for firewall policies (zone-based rules)
        let urlString = "https://\(host)/proxy/network/v2/api/site/\(siteName)/firewall-policies"
        guard let url = URL(string: urlString) else {
            throw UniFiAPIError.invalidURL
        }

        logger.info("Fetching firewall policies from: \(urlString)")

        var request = buildSessionRequest(url: url, method: "GET")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")

        // Log cookies being sent
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            logger.info("Sending \(cookies.count) cookies with firewall request")
            for cookie in cookies {
                logger.debug("Cookie: \(cookie.name)")
            }
        } else {
            logger.warning("No cookies found for firewall request!")
        }

        // v2 API returns array directly, not wrapped in {data: [...]}
        let policies: [FirewallPolicyDTO] = try await executeArray(request)
        logger.info("Firewall policies API returned \(policies.count) rules")

        // Log schedule details for downtime rules
        for policy in policies where policy.name.lowercased().contains("downtime") {
            logger.info("Downtime rule '\(policy.name)': schedule mode=\(policy.schedule?.mode ?? "nil"), start=\(policy.schedule?.timeRangeStart ?? "nil"), end=\(policy.schedule?.timeRangeEnd ?? "nil"), repeatDays=\(policy.schedule?.repeatOnDays?.joined(separator: ",") ?? "nil")")
        }

        return policies
    }

    // Execute request expecting array response (for v2 API)
    private func executeArray<T: Decodable>(_ request: URLRequest) async throws -> [T] {
        let data: Data
        let response: URLResponse

        logger.debug("Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "nil")")

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw UniFiAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UniFiAPIError.networkError(NSError(domain: "UniFiAPI", code: -1))
        }

        logger.debug("Response: \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            logger.debug("Response body: \(responseString.prefix(500))")
            // Log raw JSON for downtime rules to debug schedule parsing
            if responseString.lowercased().contains("downtime") {
                if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for item in jsonArray {
                        if let name = item["name"] as? String, name.lowercased().contains("downtime") {
                            if let schedule = item["schedule"] as? [String: Any] {
                                logger.info("RAW SCHEDULE JSON for '\(name)': \(schedule)")
                            } else {
                                logger.warning("NO SCHEDULE field found for '\(name)'")
                            }
                        }
                    }
                }
            }
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try JSONDecoder().decode([T].self, from: data)
            } catch {
                logger.error("Decoding error: \(error.localizedDescription)")
                throw UniFiAPIError.decodingError(error)
            }
        case 401:
            throw UniFiAPIError.unauthorized
        case 404:
            throw UniFiAPIError.notFound
        default:
            throw UniFiAPIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Get Single Firewall Policy (v2 API)

    func getFirewallPolicy(policyId: String) async throws -> FirewallPolicyDTO {
        try await ensureLoggedIn()

        let siteName = siteId.isEmpty ? "default" : siteId
        let urlString = "https://\(host)/proxy/network/v2/api/site/\(siteName)/firewall-policies/\(policyId)"

        guard let url = URL(string: urlString) else {
            throw UniFiAPIError.invalidURL
        }

        logger.info("Getting firewall policy: \(urlString)")
        let request = buildSessionRequest(url: url, method: "GET")
        return try await execute(request)
    }

    // MARK: - Update Firewall Policy (v2 API)

    func updateFirewallPolicy(policyId: String, update: [String: Any]) async throws -> FirewallPolicyDTO {
        try await ensureLoggedIn()

        let siteName = siteId.isEmpty ? "default" : siteId
        let urlString = "https://\(host)/proxy/network/v2/api/site/\(siteName)/firewall-policies/\(policyId)"

        guard let url = URL(string: urlString) else {
            throw UniFiAPIError.invalidURL
        }

        logger.info("Updating firewall policy: \(urlString)")
        logger.info("CSRF token present: \(self.csrfToken != nil), value prefix: \(self.csrfToken?.prefix(20) ?? "nil")")
        var request = buildSessionRequest(url: url, method: "PUT")
        request.httpBody = try JSONSerialization.data(withJSONObject: update)

        // Log the request body
        if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            logger.info("PUT body: \(bodyString)")
        }

        // Log cookies being sent
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            logger.info("Sending \(cookies.count) cookies with PUT request: \(cookies.map { $0.name }.joined(separator: ", "))")
        }

        return try await execute(request)
    }

    // MARK: - Toggle Firewall Rule Schedule (v2 API)

    /// Toggle between "ALWAYS" (block now) and scheduled mode
    /// - Parameters:
    ///   - ruleId: The firewall policy ID
    ///   - blockNow: If true, sets schedule to ALWAYS. If false, reverts to EVERY_DAY with given times.
    ///   - scheduleStart: Start time for daily schedule (e.g., "23:00")
    ///   - scheduleEnd: End time for daily schedule (e.g., "07:00")
    func toggleFirewallSchedule(
        ruleId: String,
        blockNow: Bool,
        scheduleStart: String?,
        scheduleEnd: String?
    ) async throws -> FirewallPolicyDTO {
        // First, fetch the current policy to get all fields
        let currentPolicy = try await getFirewallPolicyRaw(policyId: ruleId)

        // Modify only the schedule
        var updatedPolicy = currentPolicy
        if blockNow {
            // Set to ALWAYS - blocks immediately
            updatedPolicy["schedule"] = ["mode": "ALWAYS"]
            logger.info("Setting schedule to ALWAYS (block now)")
        } else {
            // Revert to scheduled mode
            if let start = scheduleStart, let end = scheduleEnd {
                // We have stored schedule times - use EVERY_DAY
                let scheduleDict: [String: Any] = [
                    "mode": "EVERY_DAY",
                    "time_range_start": start,
                    "time_range_end": end
                ]
                updatedPolicy["schedule"] = scheduleDict
                logger.info("Restoring EVERY_DAY schedule: \(start) - \(end)")
            } else {
                // No stored schedule - use ONE_TIME_ONLY with a past date
                // This effectively disables the rule by setting it to a time that has already passed
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let pastDate = dateFormatter.string(from: yesterday)

                let scheduleDict: [String: Any] = [
                    "mode": "ONE_TIME_ONLY",
                    "date": pastDate,
                    "time_range_start": "00:00",
                    "time_range_end": "00:01"
                ]
                updatedPolicy["schedule"] = scheduleDict
                logger.info("No stored schedule - using ONE_TIME_ONLY with past date: \(pastDate)")
            }
        }

        logger.info("Updating firewall schedule: blockNow=\(blockNow)")
        return try await updateFirewallPolicyFull(policyId: ruleId, policy: updatedPolicy)
    }

    /// Get firewall policy as raw dictionary (for modification)
    private func getFirewallPolicyRaw(policyId: String) async throws -> [String: Any] {
        try await ensureLoggedIn()

        let siteName = siteId.isEmpty ? "default" : siteId
        let urlString = "https://\(host)/proxy/network/v2/api/site/\(siteName)/firewall-policies/\(policyId)"

        guard let url = URL(string: urlString) else {
            throw UniFiAPIError.invalidURL
        }

        logger.info("Fetching policy for update: \(urlString)")
        let request = buildSessionRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UniFiAPIError.networkError(NSError(domain: "UniFiAPI", code: -1))
        }

        logger.info("GET policy response: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw UniFiAPIError.notFound
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UniFiAPIError.decodingError(NSError(domain: "UniFiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"]))
        }

        return json
    }

    /// Update firewall policy with full object
    private func updateFirewallPolicyFull(policyId: String, policy: [String: Any]) async throws -> FirewallPolicyDTO {
        try await ensureLoggedIn()

        let siteName = siteId.isEmpty ? "default" : siteId
        let urlString = "https://\(host)/proxy/network/v2/api/site/\(siteName)/firewall-policies/\(policyId)"

        guard let url = URL(string: urlString) else {
            throw UniFiAPIError.invalidURL
        }

        logger.info("Updating firewall policy (full object): \(urlString)")
        logger.info("CSRF token present: \(self.csrfToken != nil)")

        var request = buildSessionRequest(url: url, method: "PUT")
        request.httpBody = try JSONSerialization.data(withJSONObject: policy)

        // Log cookies being sent
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            logger.info("Sending \(cookies.count) cookies with PUT: \(cookies.map { $0.name }.joined(separator: ", "))")
        }

        return try await execute(request)
    }

    /// Legacy toggle for enabled state (kept for backward compatibility)
    func toggleFirewallRule(ruleId: String, enabled: Bool) async throws -> FirewallPolicyDTO {
        let update: [String: Any] = ["enabled": enabled]
        return try await updateFirewallPolicy(policyId: ruleId, update: update)
    }

    // MARK: - Verify Connection

    func verifyConnection() async throws -> Bool {
        _ = try await listACLRules(limit: 1)
        return true
    }

    // MARK: - Private Helpers

    private func buildURL(path: String, query: [String: String]? = nil) throws -> URL {
        guard !baseURL.isEmpty else {
            throw UniFiAPIError.invalidURL
        }

        var urlString = baseURL + path

        if let query = query, !query.isEmpty {
            let queryString = query.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }

        guard let url = URL(string: urlString) else {
            throw UniFiAPIError.invalidURL
        }

        return url
    }

    private func buildRequest(url: URL, method: String) throws -> URLRequest {
        guard let apiKey = try? KeychainService.shared.getAPIKey() else {
            throw UniFiAPIError.noAPIKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
    }

    private func buildSessionRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add CSRF token if available
        if let csrf = csrfToken {
            request.setValue(csrf, forHTTPHeaderField: "X-CSRF-Token")
        }

        // Cookies are automatically attached by HTTPCookieStorage

        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        logger.debug("Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "nil")")

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw UniFiAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type")
            throw UniFiAPIError.networkError(
                NSError(domain: "UniFiAPI", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid response type"
                ])
            )
        }

        logger.debug("Response: \(httpResponse.statusCode)")

        // Log response body for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            logger.debug("Response body: \(responseString.prefix(500))")
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.error("Decoding error: \(error.localizedDescription)")
                throw UniFiAPIError.decodingError(error)
            }
        case 400:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw UniFiAPIError.badRequest(message)
        case 401:
            // Session expired - clear it so next ensureLoggedIn() will re-login
            logger.warning("Got 401 - session expired, clearing session")
            isLoggedIn = false
            throw UniFiAPIError.unauthorized
        case 404:
            throw UniFiAPIError.notFound
        default:
            throw UniFiAPIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - JWT Helpers

    /// Extract csrfToken from JWT payload
    /// JWT format: header.payload.signature (base64 encoded)
    private func extractCsrfFromJWT(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else {
            logger.warning("Invalid JWT format - expected 3 parts, got \(parts.count)")
            return nil
        }

        // Payload is the second part (index 1)
        var payload = String(parts[1])

        // Base64 requires padding to be multiple of 4
        let paddingNeeded = (4 - payload.count % 4) % 4
        payload += String(repeating: "=", count: paddingNeeded)

        // JWT uses URL-safe base64 (replace - with + and _ with /)
        payload = payload.replacingOccurrences(of: "-", with: "+")
        payload = payload.replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: payload) else {
            logger.warning("Failed to base64 decode JWT payload")
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.warning("Failed to parse JWT payload as JSON")
            return nil
        }

        guard let csrfToken = json["csrfToken"] as? String else {
            logger.warning("No csrfToken found in JWT payload")
            return nil
        }

        return csrfToken
    }
}
