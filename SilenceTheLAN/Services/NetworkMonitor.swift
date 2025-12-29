import Foundation
import Network
import Combine
import os.log

private let logger = Logger(subsystem: "com.silencethelan", category: "NetworkMonitor")

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var isWiFi = false
    @Published private(set) var isReachable = false
    @Published private(set) var configuredHost: String?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    // Guard against concurrent reachability checks
    private var isCheckingReachability = false
    private var pendingReachabilityCheck = false

    // Shared session for reachability checks - use short timeout for quick checks
    private lazy var reachabilitySession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2  // Reduced from 3 for faster checks
        config.timeoutIntervalForResource = 2
        return URLSession(
            configuration: config,
            delegate: SSLTrustDelegate(),
            delegateQueue: nil
        )
    }()

    private init() {
        logger.info("NetworkMonitor initialized")
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isWiFi = path.usesInterfaceType(.wifi)

                logger.info("Network path update: status=\(path.status == .satisfied ? "connected" : "disconnected"), wifi=\(path.usesInterfaceType(.wifi))")

                // When network changes and we have a host, schedule a reachability check
                if path.status == .satisfied, let host = self?.configuredHost {
                    await self?.scheduleReachabilityCheck(host: host)
                } else {
                    self?.isReachable = false
                }
            }
        }
        monitor.start(queue: queue)
    }

    func configure(host: String) {
        logger.info("NetworkMonitor.configure called with host: \(host)")
        self.configuredHost = host
        // Assume reachable initially to avoid blocking UI, then verify in background
        self.isReachable = true
        Task {
            await scheduleReachabilityCheck(host: host)
        }
    }

    /// Ensure reachability has been checked - non-blocking
    func ensureReachabilityChecked() async {
        guard let host = configuredHost else {
            logger.warning("ensureReachabilityChecked: No host configured")
            return
        }
        await scheduleReachabilityCheck(host: host)
    }

    /// Mark host as reachable (called when API calls succeed)
    func markReachable() {
        if !isReachable {
            logger.info("markReachable: Host marked as reachable by successful API call")
            isReachable = true
        }
    }

    /// Mark host as unreachable (called when API calls fail with network errors)
    func markUnreachable() {
        if isReachable {
            logger.info("markUnreachable: Host marked as unreachable")
            isReachable = false
        }
    }

    /// Schedule a reachability check, debouncing concurrent requests
    private func scheduleReachabilityCheck(host: String) async {
        if isCheckingReachability {
            // Already checking - mark that we need another check after
            pendingReachabilityCheck = true
            logger.info("scheduleReachabilityCheck: Already checking, will retry after")
            return
        }

        isCheckingReachability = true
        defer {
            isCheckingReachability = false
            // If a check was requested while we were checking, do one more
            if pendingReachabilityCheck {
                pendingReachabilityCheck = false
                Task {
                    await scheduleReachabilityCheck(host: host)
                }
            }
        }

        await performReachabilityCheck(host: host)
    }

    /// Actually perform the reachability check - tries endpoints in parallel for speed
    private func performReachabilityCheck(host: String) async {
        logger.info("performReachabilityCheck starting for host: \(host)")

        // Try endpoints in parallel - first success wins
        let endpoints = [
            "https://\(host)/proxy/network/api/s/default/self",  // Network app API - most reliable
            "https://\(host)/",  // Root page
            "https://\(host)/api/system/info"  // UniFi OS API - can be slow/timeout
        ]

        // Use TaskGroup to check all endpoints in parallel
        let result = await withTaskGroup(of: (String, Int?).self) { group in
            for endpoint in endpoints {
                group.addTask {
                    guard let url = URL(string: endpoint) else { return (endpoint, nil) }

                    do {
                        var request = URLRequest(url: url)
                        request.httpMethod = "GET"
                        request.setValue("application/json", forHTTPHeaderField: "Accept")

                        let (_, response) = try await self.reachabilitySession.data(for: request)

                        if let httpResponse = response as? HTTPURLResponse {
                            return (endpoint, httpResponse.statusCode)
                        }
                    } catch {
                        // Endpoint failed
                    }
                    return (endpoint, nil)
                }
            }

            // Return the first successful result (any status code 200-599 means reachable)
            for await (endpoint, statusCode) in group {
                if let code = statusCode, (200...599).contains(code) {
                    logger.info("performReachabilityCheck: \(endpoint) responded with \(code), isReachable=true")
                    // Cancel remaining tasks
                    group.cancelAll()
                    return true
                }
            }
            return false
        }

        if result {
            isReachable = true
        } else {
            logger.warning("performReachabilityCheck: All endpoints failed, isReachable=false")
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
