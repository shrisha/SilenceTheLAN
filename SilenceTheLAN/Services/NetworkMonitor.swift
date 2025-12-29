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
    @Published private(set) var isReachable = true  // Assume reachable until API call fails
    @Published private(set) var configuredHost: String?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        logger.info("NetworkMonitor initialized")
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.isWiFi = path.usesInterfaceType(.wifi)

                logger.info("Network path update: status=\(path.status == .satisfied ? "connected" : "disconnected"), wifi=\(path.usesInterfaceType(.wifi))")

                // If we lost network connection, mark as unreachable
                if wasConnected && path.status != .satisfied {
                    self.isReachable = false
                }
                // If we regained network, assume reachable (API call will confirm)
                if !wasConnected && path.status == .satisfied {
                    self.isReachable = true
                }
            }
        }
        monitor.start(queue: queue)
    }

    func configure(host: String) {
        logger.info("NetworkMonitor.configure called with host: \(host)")
        self.configuredHost = host
        // Assume reachable - API calls will update this if they fail
        self.isReachable = true
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
            logger.info("markUnreachable: Host marked as unreachable due to network error")
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
