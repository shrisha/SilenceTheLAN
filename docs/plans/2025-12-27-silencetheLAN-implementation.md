# SilenceTheLAN MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an iOS app that lets parents toggle "downtime" ACL rules on their UniFi network with a gorgeous dark theme UI.

**Architecture:** MVVM with SwiftUI views binding to ObservableObject ViewModels that call async Service classes. SwiftData for persistence, Keychain for API key storage. Network layer handles SSL trust for self-signed UniFi certificates.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, URLSession async/await, iOS 17.0+

---

## Task 1: Project Structure Setup

**Files:**
- Create: `SilenceTheLAN/Models/AppConfiguration.swift`
- Create: `SilenceTheLAN/Models/ACLRule.swift`
- Create: `SilenceTheLAN/Services/KeychainService.swift`
- Create: `SilenceTheLAN/Services/UniFiAPIService.swift`
- Create: `SilenceTheLAN/Services/NetworkMonitor.swift`
- Create: `SilenceTheLAN/ViewModels/AppState.swift`
- Delete: `SilenceTheLAN/Item.swift` (template file)

**Step 1: Create folder structure**

In Xcode or Finder, create these folders inside `SilenceTheLAN/`:
- `Models/`
- `Services/`
- `ViewModels/`
- `Views/`
- `Views/Onboarding/`
- `Views/Dashboard/`
- `Views/Settings/`

**Step 2: Delete template file**

Delete `SilenceTheLAN/Item.swift` - it's the Xcode template placeholder.

**Step 3: Commit structure**

```bash
git add -A
git commit -m "chore: set up project folder structure"
```

---

## Task 2: SwiftData Models

**Files:**
- Create: `SilenceTheLAN/Models/AppConfiguration.swift`
- Create: `SilenceTheLAN/Models/ACLRule.swift`

**Step 1: Create AppConfiguration model**

Create `SilenceTheLAN/Models/AppConfiguration.swift`:

```swift
import Foundation
import SwiftData

@Model
final class AppConfiguration {
    var unifiHost: String
    var siteId: String
    var isConfigured: Bool
    var lastUpdated: Date

    init(
        unifiHost: String = "",
        siteId: String = "",
        isConfigured: Bool = false,
        lastUpdated: Date = Date()
    ) {
        self.unifiHost = unifiHost
        self.siteId = siteId
        self.isConfigured = isConfigured
        self.lastUpdated = lastUpdated
    }
}
```

**Step 2: Create ACLRule model**

Create `SilenceTheLAN/Models/ACLRule.swift`:

```swift
import Foundation
import SwiftData

@Model
final class ACLRule {
    // Identity
    @Attribute(.unique) var ruleId: String

    // Required fields for PUT requests
    var ruleType: String      // "IPV4" or "IPV6"
    var name: String
    var action: String        // "ALLOW" or "BLOCK"
    var index: Int
    var isEnabled: Bool

    // Optional fields
    var ruleDescription: String?

    // App-specific
    var isSelected: Bool
    var lastSynced: Date

    // Store complex filter objects as JSON for PUT requests
    var sourceFilterJSON: String?
    var destinationFilterJSON: String?
    var protocolFilterJSON: String?
    var enforcingDeviceFilterJSON: String?

    /// Display name extracted from rule name (e.g., "Downtime-Rishi" → "Rishi")
    var displayName: String {
        let prefix = "downtime-"
        if name.lowercased().hasPrefix(prefix) {
            return String(name.dropFirst(prefix.count))
        }
        return name
    }

    init(
        ruleId: String,
        ruleType: String = "IPV4",
        name: String,
        action: String = "BLOCK",
        index: Int = 0,
        isEnabled: Bool = false,
        ruleDescription: String? = nil,
        isSelected: Bool = false,
        lastSynced: Date = Date()
    ) {
        self.ruleId = ruleId
        self.ruleType = ruleType
        self.name = name
        self.action = action
        self.index = index
        self.isEnabled = isEnabled
        self.ruleDescription = ruleDescription
        self.isSelected = isSelected
        self.lastSynced = lastSynced
    }
}
```

**Step 3: Build to verify models compile**

In Xcode: `Cmd+B` or run:
```bash
xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

**Step 4: Commit models**

```bash
git add SilenceTheLAN/Models/
git commit -m "feat: add SwiftData models for AppConfiguration and ACLRule"
```

---

## Task 3: Keychain Service

**Files:**
- Create: `SilenceTheLAN/Services/KeychainService.swift`

**Step 1: Create KeychainService**

Create `SilenceTheLAN/Services/KeychainService.swift`:

```swift
import Foundation
import Security

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case invalidData
}

final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.silencetheLAN.api"
    private let account = "unifi-api-key"

    private init() {}

    func saveAPIKey(_ apiKey: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Try to delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func getAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return apiKey
    }

    func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    var hasAPIKey: Bool {
        (try? getAPIKey()) != nil
    }
}
```

**Step 2: Build to verify**

```bash
xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add SilenceTheLAN/Services/KeychainService.swift
git commit -m "feat: add KeychainService for secure API key storage"
```

---

## Task 4: Network Monitor

**Files:**
- Create: `SilenceTheLAN/Services/NetworkMonitor.swift`

**Step 1: Create NetworkMonitor**

Create `SilenceTheLAN/Services/NetworkMonitor.swift`:

```swift
import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var isWiFi = false
    @Published private(set) var isReachable = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private var unifiHost: String?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isWiFi = path.usesInterfaceType(.wifi)

                // When network changes, check UniFi reachability
                if path.status == .satisfied, let host = self?.unifiHost {
                    await self?.checkReachability(host: host)
                } else {
                    self?.isReachable = false
                }
            }
        }
        monitor.start(queue: queue)
    }

    func configure(host: String) {
        self.unifiHost = host
        Task {
            await checkReachability(host: host)
        }
    }

    func checkReachability(host: String) async {
        guard let url = URL(string: "https://\(host)") else {
            isReachable = false
            return
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5

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
                isReachable = (200...499).contains(httpResponse.statusCode)
            } else {
                isReachable = false
            }
        } catch {
            isReachable = false
        }
    }
}

// SSL Trust Delegate for self-signed certificates
final class SSLTrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Trust self-signed certificates for local UniFi controller
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
```

**Step 2: Build to verify**

```bash
xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add SilenceTheLAN/Services/NetworkMonitor.swift
git commit -m "feat: add NetworkMonitor for connectivity and UniFi reachability"
```

---

## Task 5: UniFi API Service - Data Types

**Files:**
- Create: `SilenceTheLAN/Services/UniFiAPIService.swift`

**Step 1: Create API service with data types**

Create `SilenceTheLAN/Services/UniFiAPIService.swift`:

```swift
import Foundation

// MARK: - API Response Types

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
```

**Step 2: Build to verify**

```bash
xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add SilenceTheLAN/Services/UniFiAPIService.swift
git commit -m "feat: add UniFi API data types and error handling"
```

---

## Task 6: UniFi API Service - Implementation

**Files:**
- Modify: `SilenceTheLAN/Services/UniFiAPIService.swift`

**Step 1: Add the API service class**

Append to `SilenceTheLAN/Services/UniFiAPIService.swift`:

```swift
// MARK: - API Service

final class UniFiAPIService {
    private let session: URLSession
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
        self.baseURL = "https://\(host)/proxy/network/integration/v1/sites/\(siteId)"
        self.siteId = siteId
    }

    // MARK: - List ACL Rules

    func listACLRules(limit: Int = 200) async throws -> [ACLRuleDTO] {
        let url = try buildURL(path: "/acl-rules", query: ["limit": "\(limit)"])
        let request = try buildRequest(url: url, method: "GET")

        let response: ACLRuleListResponse = try await execute(request)
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

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UniFiAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UniFiAPIError.networkError(
                NSError(domain: "UniFiAPI", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid response type"
                ])
            )
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
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
```

**Step 2: Build to verify**

```bash
xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add SilenceTheLAN/Services/UniFiAPIService.swift
git commit -m "feat: implement UniFi API service with list, get, update, toggle"
```

---

## Task 7: App State ViewModel

**Files:**
- Create: `SilenceTheLAN/ViewModels/AppState.swift`

**Step 1: Create AppState**

Create `SilenceTheLAN/ViewModels/AppState.swift`:

```swift
import Foundation
import SwiftUI
import SwiftData

@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State

    @Published var isConfigured = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var rules: [ACLRule] = []
    @Published var togglingRuleIds: Set<String> = []

    // MARK: - Services

    let api = UniFiAPIService()
    let networkMonitor = NetworkMonitor.shared

    // MARK: - SwiftData

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadConfiguration()
    }

    // MARK: - Configuration

    private func loadConfiguration() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<AppConfiguration>()

        if let config = try? context.fetch(descriptor).first,
           config.isConfigured {
            api.configure(host: config.unifiHost, siteId: config.siteId)
            networkMonitor.configure(host: config.unifiHost)
            isConfigured = true
            loadCachedRules()
        }
    }

    func saveConfiguration(host: String, siteId: String) {
        guard let context = modelContext else { return }

        // Delete existing config
        let descriptor = FetchDescriptor<AppConfiguration>()
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { context.delete($0) }
        }

        // Create new config
        let config = AppConfiguration(
            unifiHost: host,
            siteId: siteId,
            isConfigured: true,
            lastUpdated: Date()
        )
        context.insert(config)

        try? context.save()

        api.configure(host: host, siteId: siteId)
        networkMonitor.configure(host: host)
        isConfigured = true
    }

    func resetConfiguration() {
        guard let context = modelContext else { return }

        // Delete config
        let configDescriptor = FetchDescriptor<AppConfiguration>()
        if let configs = try? context.fetch(configDescriptor) {
            configs.forEach { context.delete($0) }
        }

        // Delete rules
        let ruleDescriptor = FetchDescriptor<ACLRule>()
        if let rules = try? context.fetch(ruleDescriptor) {
            rules.forEach { context.delete($0) }
        }

        try? context.save()
        try? KeychainService.shared.deleteAPIKey()

        isConfigured = false
        rules = []
    }

    // MARK: - Rules

    private func loadCachedRules() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.isSelected },
            sortBy: [SortDescriptor(\.name)]
        )

        rules = (try? context.fetch(descriptor)) ?? []
    }

    func refreshRules() async {
        guard networkMonitor.isReachable else {
            errorMessage = "Cannot reach UniFi controller"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let remoteDTOs = try await api.listACLRules()
            await updateCachedRules(from: remoteDTOs)
            loadCachedRules()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func updateCachedRules(from dtos: [ACLRuleDTO]) async {
        guard let context = modelContext else { return }

        for dto in dtos {
            let descriptor = FetchDescriptor<ACLRule>(
                predicate: #Predicate { $0.ruleId == dto.id }
            )

            if let existing = try? context.fetch(descriptor).first {
                // Update existing rule
                existing.isEnabled = dto.enabled
                existing.name = dto.name
                existing.action = dto.action
                existing.index = dto.index
                existing.ruleDescription = dto.description
                existing.lastSynced = Date()
            }
            // Don't create new rules here - that's done during selection
        }

        try? context.save()
    }

    func saveSelectedRules(_ dtos: [ACLRuleDTO]) {
        guard let context = modelContext else { return }

        // Clear existing rules
        let descriptor = FetchDescriptor<ACLRule>()
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { context.delete($0) }
        }

        // Create new selected rules
        for dto in dtos {
            let rule = ACLRule(
                ruleId: dto.id,
                ruleType: dto.type,
                name: dto.name,
                action: dto.action,
                index: dto.index,
                isEnabled: dto.enabled,
                ruleDescription: dto.description,
                isSelected: true,
                lastSynced: Date()
            )

            // Store filter JSON for PUT requests
            let encoder = JSONEncoder()
            if let sourceFilter = dto.sourceFilter {
                rule.sourceFilterJSON = try? String(data: encoder.encode(sourceFilter), encoding: .utf8)
            }
            if let destFilter = dto.destinationFilter {
                rule.destinationFilterJSON = try? String(data: encoder.encode(destFilter), encoding: .utf8)
            }
            if let protoFilter = dto.protocolFilter {
                rule.protocolFilterJSON = try? String(data: encoder.encode(protoFilter), encoding: .utf8)
            }

            context.insert(rule)
        }

        try? context.save()
        loadCachedRules()
    }

    // MARK: - Toggle

    func toggleRule(_ rule: ACLRule) async {
        guard !togglingRuleIds.contains(rule.ruleId) else { return }

        let previousState = rule.isEnabled
        let newState = !previousState

        // Optimistic update
        togglingRuleIds.insert(rule.ruleId)
        rule.isEnabled = newState

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        do {
            _ = try await api.toggleRule(ruleId: rule.ruleId, enabled: newState)

            // Success haptic
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)

            rule.lastSynced = Date()
            try? modelContext?.save()

        } catch {
            // Revert on failure
            rule.isEnabled = previousState

            // Error haptic
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)

            errorMessage = error.localizedDescription
        }

        togglingRuleIds.remove(rule.ruleId)
    }
}
```

**Step 2: Build to verify**

```bash
xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add SilenceTheLAN/ViewModels/AppState.swift
git commit -m "feat: add AppState ViewModel with toggle, caching, and configuration"
```

---

## Task 8: Update App Entry Point

**Files:**
- Modify: `SilenceTheLAN/SilenceTheLANApp.swift`

**Step 1: Update app entry point**

Replace contents of `SilenceTheLAN/SilenceTheLANApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct SilenceTheLANApp: App {
    @StateObject private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppConfiguration.self,
            ACLRule.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    appState.configure(modelContext: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
```

**Step 2: Create placeholder RootView**

Create `SilenceTheLAN/Views/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isConfigured {
                DashboardView()
            } else {
                WelcomeView()
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
```

**Step 3: Create placeholder views**

Create `SilenceTheLAN/Views/Dashboard/DashboardView.swift`:

```swift
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Text("Dashboard - Coming Soon")
            .foregroundStyle(.white)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
```

Create `SilenceTheLAN/Views/Onboarding/WelcomeView.swift`:

```swift
import SwiftUI

struct WelcomeView: View {
    var body: some View {
        Text("Welcome - Coming Soon")
            .foregroundStyle(.white)
    }
}

#Preview {
    WelcomeView()
        .preferredColorScheme(.dark)
}
```

**Step 4: Delete old ContentView**

Delete `SilenceTheLAN/ContentView.swift`

**Step 5: Build to verify**

```bash
xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: update app entry point with SwiftData and AppState"
```

---

## Task 9: Onboarding Views (Use frontend-design skill)

**Files:**
- Modify: `SilenceTheLAN/Views/Onboarding/WelcomeView.swift`
- Create: `SilenceTheLAN/Views/Onboarding/SetupView.swift`
- Create: `SilenceTheLAN/Views/Onboarding/RuleSelectionView.swift`
- Create: `SilenceTheLAN/ViewModels/SetupViewModel.swift`

> **REQUIRED:** Use `frontend-design:frontend-design` skill to create gorgeous dark theme UI for these views.

**Step 1: Create SetupViewModel**

Create `SilenceTheLAN/ViewModels/SetupViewModel.swift`:

```swift
import Foundation
import SwiftUI

@MainActor
final class SetupViewModel: ObservableObject {
    @Published var currentStep: SetupStep = .welcome
    @Published var host: String = ""
    @Published var apiKey: String = ""
    @Published var siteId: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var discoveredHost: String?
    @Published var availableRules: [ACLRuleDTO] = []
    @Published var selectedRuleIds: Set<String> = []

    enum SetupStep {
        case welcome
        case discovery
        case apiKey
        case siteId
        case ruleSelection
        case complete
    }

    private let api = UniFiAPIService()

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
            api.configure(host: host, siteId: "default") // Temporary siteId

            // Try to fetch rules to verify API key works
            // This will fail if siteId is wrong, but that's OK - we just want to check auth
            _ = try await api.listACLRules(limit: 1)

            isLoading = false
            return true
        } catch UniFiAPIError.unauthorized {
            errorMessage = "Invalid API key"
            try? KeychainService.shared.deleteAPIKey()
        } catch {
            // Other errors might be siteId related, which is fine
            isLoading = false
            return true
        }

        isLoading = false
        return false
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

    func getSelectedRules() -> [ACLRuleDTO] {
        availableRules.filter { selectedRuleIds.contains($0.id) }
    }
}
```

**Step 2: Build to verify**

```bash
xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add SilenceTheLAN/ViewModels/SetupViewModel.swift
git commit -m "feat: add SetupViewModel for onboarding flow"
```

**Step 4: Invoke frontend-design skill for UI**

> At this point, invoke the `frontend-design:frontend-design` skill to create the gorgeous dark theme UI for:
> - WelcomeView
> - SetupView (host discovery, API key entry, site ID)
> - RuleSelectionView
> - DashboardView with toggle cards

---

## Task 10: Dashboard UI (Use frontend-design skill)

**Files:**
- Modify: `SilenceTheLAN/Views/Dashboard/DashboardView.swift`
- Create: `SilenceTheLAN/Views/Dashboard/RuleCardView.swift`

> **REQUIRED:** Use `frontend-design:frontend-design` skill to create:
> - Dashboard with rule cards
> - RuleCardView with toggle, glow effects, loading shimmer
> - Offline state banner
> - Pull-to-refresh

---

## Task 11: Settings View

**Files:**
- Create: `SilenceTheLAN/Views/Settings/SettingsView.swift`

> **REQUIRED:** Use `frontend-design:frontend-design` skill for consistent dark theme styling.

---

## Task 12: Final Integration & Testing

**Step 1: Run on simulator**

```bash
xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build
xcrun simctl boot "iPhone 16"
xcrun simctl install booted build/Debug-iphonesimulator/SilenceTheLAN.app
xcrun simctl launch booted com.yourcompany.SilenceTheLAN
```

**Step 2: Test on physical device**

- Connect iPhone to Mac
- In Xcode: Select your device, click Run
- Complete onboarding with your UniFi details
- Test toggle functionality

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete SilenceTheLAN MVP implementation"
```

---

## Summary

| Task | Description | Status |
|------|-------------|--------|
| 1 | Project structure | Pending |
| 2 | SwiftData models | Pending |
| 3 | Keychain service | Pending |
| 4 | Network monitor | Pending |
| 5 | API data types | Pending |
| 6 | API implementation | Pending |
| 7 | AppState ViewModel | Pending |
| 8 | App entry point | Pending |
| 9 | Onboarding views (frontend-design) | Pending |
| 10 | Dashboard UI (frontend-design) | Pending |
| 11 | Settings view | Pending |
| 12 | Integration & testing | Pending |
