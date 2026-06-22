import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - Provider Health

public struct ProviderHealth: Sendable {
    public let providerName: String
    public let reachable: Bool
    public let latencyMs: Int
    public let lastError: String?
    public let lastChecked: Date

    public init(providerName: String, reachable: Bool, latencyMs: Int, lastError: String?, lastChecked: Date) {
        self.providerName = providerName
        self.reachable = reachable
        self.latencyMs = latencyMs
        self.lastError = lastError
        self.lastChecked = lastChecked
    }
}

private struct TimeoutError: Error, LocalizedError {
    var errorDescription: String? { "请求超时" }
}

extension AssistantSessionController {

    private func withThrowingTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
            guard let result = try await group.next() else {
                group.cancelAll()
                throw TimeoutError()
            }
            group.cancelAll()
            return result
        }
    }

    private func pingProvider(kind: ProviderKind) async -> ProviderHealth {
        let start = Date()
        let endpoint = endpoint(for: kind)

        // For local endpoints, do a quick TCP reachability check first
        if kind == .localOpenAICompatible || kind == .appleNative, let host = endpoint.baseURL?.host {
            let port = endpoint.baseURL?.port ?? (endpoint.baseURL?.scheme == "https" ? 443 : 80)
            let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            let reachable: Bool
            if socket >= 0 {
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = CFSwapInt16HostToBig(UInt16(port))
                if let hostEntry = gethostbyname(host) {
                    addr.sin_addr = hostEntry.pointee.h_addr_list.pointee?.withMemoryRebound(to: in_addr.self, capacity: 1) { $0.pointee } ?? in_addr()
                }
                var timeval = timeval(tv_sec: 2, tv_usec: 0)
                _ = withUnsafeMutablePointer(to: &timeval) {
                    setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, $0, socklen_t(MemoryLayout<timeval>.size))
                }
                reachable = Darwin.connect(socket, withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 } }, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
                Darwin.close(socket)
            } else {
                reachable = false
            }
            guard reachable else {
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                return ProviderHealth(providerName: kind.title, reachable: false, latencyMs: ms, lastError: "本地服务未运行 (\(host):\(port))", lastChecked: Date())
            }
        }

        let provider = OpenAICompatibleChatProvider(endpoint: endpoint, apiKey: providerKeys[endpoint.apiKeyEnvironmentVariable])
        do {
            let request = ChatRequest(
                model: endpoint.model,
                messages: [ChatMessage(role: "user", content: "ping")],
                temperature: 0,
                maxTokens: 1
            )
            _ = try await withThrowingTimeout(seconds: 5) {
                _ = try await provider.complete(request)
            }
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            return ProviderHealth(providerName: kind.title, reachable: true, latencyMs: ms, lastError: nil, lastChecked: Date())
        } catch {
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            let errorDescription = error is TimeoutError ? "超时（5s）" : error.localizedDescription
            return ProviderHealth(providerName: kind.title, reachable: false, latencyMs: ms, lastError: errorDescription, lastChecked: Date())
        }
    }

    public func runProviderHealthCheck() {
        Task {
            var snapshots: [ProviderHealthSnapshot] = []
            for preference in ProviderPreference.selectableCases {
                let kind = providerKind(for: preference)
                let endpoint = endpoint(for: kind)
                let hasKey = endpoint.apiKeyEnvironmentVariable.isEmpty || providerKeys[endpoint.apiKeyEnvironmentVariable]?.isEmpty == false || OpenAIAPIKeyStore.load(account: endpoint.apiKeyEnvironmentVariable)?.isEmpty == false
                if hasKey || kind == .localOpenAICompatible {
                    let health = await pingProvider(kind: kind)
                    let status: FoundationHealthStatus = health.reachable ? .ok : .failing
                    let detail = health.reachable ? "可达，延迟 \(health.latencyMs)ms" : "不可达：\(health.lastError ?? "未知错误")"
                    snapshots.append(ProviderHealthSnapshot(kind: kind, status: status, detail: detail))
                } else {
                    let status: FoundationHealthStatus = .warning
                    let detail = "缺少 \(endpoint.apiKeyEnvironmentVariable)"
                    snapshots.append(ProviderHealthSnapshot(kind: kind, status: status, detail: detail))
                }
            }
            providerHealth = snapshots
            foundationMessage = "Provider 健康检查完成。"
            await refreshFoundationState()
        }
    }
}
