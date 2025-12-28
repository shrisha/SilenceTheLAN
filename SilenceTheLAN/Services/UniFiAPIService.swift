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

// MARK: - Firewall Rule Types (REST API)

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

// MARK: - API Errors

enum UniFiAPIError: Error, LocalizedError {
    case invalidURL
    case noAPIKey
    case unauthorized
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
        case .unauthorized:
            return "API key is invalid or expired"
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

// MARK: - API Service

final class UniFiAPIService {
    private let session: URLSession
    private var host: String = ""
    private var baseURL: String = ""
    private var siteId: String = ""

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

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

    // MARK: - List Sites (for discovery)

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

    // MARK: - List Firewall Rules (REST API)

    func listFirewallRules() async throws -> [FirewallRuleDTO] {
        // REST API uses site name ("default") not UUID
        // Try to extract site name from the sites list, or use "default"
        let siteName = "default"
        let urlString = "https://\(host)/proxy/network/api/s/\(siteName)/rest/firewallrule"

        guard let url = URL(string: urlString) else {
            throw UniFiAPIError.invalidURL
        }

        let request = try buildRequest(url: url, method: "GET")
        logger.info("Fetching firewall rules from: \(urlString)")

        let response: FirewallRuleListResponse = try await execute(request)

        if response.meta.rc != "ok" {
            logger.error("Firewall rules API error: \(response.meta.msg ?? "unknown")")
            throw UniFiAPIError.badRequest(response.meta.msg ?? "API returned error")
        }

        logger.info("Found \(response.data.count) firewall rules")
        return response.data
    }

    // MARK: - Get Single Firewall Rule

    func getFirewallRule(ruleId: String) async throws -> FirewallRuleDTO {
        let siteName = "default"
        let urlString = "https://\(host)/proxy/network/api/s/\(siteName)/rest/firewallrule/\(ruleId)"

        guard let url = URL(string: urlString) else {
            throw UniFiAPIError.invalidURL
        }

        let request = try buildRequest(url: url, method: "GET")
        let response: FirewallRuleListResponse = try await execute(request)

        guard let rule = response.data.first else {
            throw UniFiAPIError.notFound
        }
        return rule
    }

    // MARK: - Update Firewall Rule

    func updateFirewallRule(ruleId: String, update: [String: Any]) async throws -> FirewallRuleDTO {
        let siteName = "default"
        let urlString = "https://\(host)/proxy/network/api/s/\(siteName)/rest/firewallrule/\(ruleId)"

        guard let url = URL(string: urlString) else {
            throw UniFiAPIError.invalidURL
        }

        var request = try buildRequest(url: url, method: "PUT")
        request.httpBody = try JSONSerialization.data(withJSONObject: update)

        let response: FirewallRuleListResponse = try await execute(request)
        guard let rule = response.data.first else {
            throw UniFiAPIError.notFound
        }
        return rule
    }

    // MARK: - Toggle Firewall Rule

    func toggleFirewallRule(ruleId: String, enabled: Bool) async throws -> FirewallRuleDTO {
        // For REST API, we can send just the enabled field
        let update: [String: Any] = ["enabled": enabled]
        return try await updateFirewallRule(ruleId: ruleId, update: update)
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
            throw UniFiAPIError.unauthorized
        case 404:
            throw UniFiAPIError.notFound
        default:
            throw UniFiAPIError.serverError(httpResponse.statusCode)
        }
    }
}
