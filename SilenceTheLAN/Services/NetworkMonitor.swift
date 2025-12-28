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

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private var unifiHost: String?

    private init() {
        logger.info("NetworkMonitor initialized")
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasConnected = self?.isConnected ?? false
                self?.isConnected = path.status == .satisfied
                self?.isWiFi = path.usesInterfaceType(.wifi)

                logger.info("Network path update: status=\(path.status == .satisfied ? "connected" : "disconnected"), wifi=\(path.usesInterfaceType(.wifi)), host=\(self?.unifiHost ?? "nil")")

                // When network changes, check UniFi reachability
                if path.status == .satisfied, let host = self?.unifiHost {
                    logger.info("Network satisfied, checking reachability for host: \(host)")
                    await self?.checkReachability(host: host)
                } else {
                    logger.warning("Network not satisfied or host not configured. status=\(path.status == .satisfied), host=\(self?.unifiHost ?? "nil")")
                    self?.isReachable = false
                }
            }
        }
        monitor.start(queue: queue)
    }

    func configure(host: String) {
        logger.info("NetworkMonitor.configure called with host: \(host)")
        self.unifiHost = host
        Task {
            await checkReachability(host: host)
        }
    }

    /// Ensure reachability has been checked - call this before using isReachable
    func ensureReachabilityChecked() async {
        guard let host = unifiHost else {
            logger.warning("ensureReachabilityChecked: No host configured")
            return
        }
        logger.info("ensureReachabilityChecked: Forcing reachability check for host: \(host)")
        await checkReachability(host: host)
    }

    func checkReachability(host: String) async {
        logger.info("checkReachability starting for host: \(host)")

        guard let url = URL(string: "https://\(host)") else {
            logger.error("checkReachability: Invalid URL for host: \(host)")
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
            logger.info("checkReachability: Making HEAD request to \(url.absoluteString)")

            let (_, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                let reachable = (200...499).contains(statusCode)
                logger.info("checkReachability: Got response statusCode=\(statusCode), setting isReachable=\(reachable)")
                isReachable = reachable
            } else {
                logger.warning("checkReachability: Response is not HTTPURLResponse")
                isReachable = false
            }
        } catch {
            logger.error("checkReachability: Error - \(error.localizedDescription)")
            logger.error("checkReachability: Full error - \(String(describing: error))")
            isReachable = false
        }

        logger.info("checkReachability completed: isReachable=\(self.isReachable)")
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
