import Foundation
import Network
import Combine

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
