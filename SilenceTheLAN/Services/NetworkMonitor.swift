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

    // Shared session for reachability checks
    private lazy var reachabilitySession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 3
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

    /// Actually perform the reachability check
    private func performReachabilityCheck(host: String) async {
        logger.info("performReachabilityCheck starting for host: \(host)")

        // Try endpoints in order of reliability for UDM Pro
        let endpoints = [
            "https://\(host)/proxy/network/api/s/default/self",  // Network app API - most reliable
            "https://\(host)/",  // Root page
            "https://\(host)/api/system/info"  // UniFi OS API - can be slow/timeout
        ]

        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }

            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("application/json", forHTTPHeaderField: "Accept")

                let (_, response) = try await reachabilitySession.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    // Any response (even 401/403) means the server is reachable
                    let reachable = (200...599).contains(statusCode)
                    if reachable {
                        logger.info("performReachabilityCheck: \(endpoint) responded with \(statusCode), isReachable=true")
                        isReachable = true
                        return
                    }
                }
            } catch {
                // Try next endpoint
                logger.info("performReachabilityCheck: \(endpoint) failed - \(error.localizedDescription)")
                continue
            }
        }

        // All endpoints failed
        logger.warning("performReachabilityCheck: All endpoints failed, isReachable=false")
        isReachable = false
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
