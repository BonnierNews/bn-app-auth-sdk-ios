import AppAuth
import Foundation

@MainActor
final class TransferTokenExchange {
    nonisolated static let tokenExchangeGrantType = "urn:ietf:params:oauth:grant-type:token-exchange"
    nonisolated static let accessTokenType = "urn:ietf:params:oauth:token-type:access_token"
    nonisolated static let sessionTransferTokenType = "urn:bonniernews:oauth:token-type:session_transfer_token"
    nonisolated static let scope = OIDScopeOpenID
    nonisolated static let invalidTarget = "invalid_target"
    nonisolated static let timeout: TimeInterval = 2
    nonisolated static let originWithoutLoginTTL: TimeInterval = 24 * 60 * 60

    private let client: @MainActor () -> BNAppAuth.ClientConfiguration?
    private let freshAccessToken: @MainActor () async throws -> String?
    private let serviceConfiguration: @MainActor () async throws -> OIDServiceConfiguration
    private let performTokenRequest: @MainActor (OIDTokenRequest) async throws -> OIDTokenResponse?
    private let timeout: TimeInterval
    private let now: @MainActor () -> Date

    private var originsWithoutLogin: [String: Date] = [:]

    nonisolated init(
        client: @escaping @MainActor () -> BNAppAuth.ClientConfiguration?,
        freshAccessToken: @escaping @MainActor () async throws -> String?,
        serviceConfiguration: @escaping @MainActor () async throws -> OIDServiceConfiguration,
        performTokenRequest: @escaping @MainActor (OIDTokenRequest) async throws -> OIDTokenResponse?,
        timeout: TimeInterval = TransferTokenExchange.timeout,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.client = client
        self.freshAccessToken = freshAccessToken
        self.serviceConfiguration = serviceConfiguration
        self.performTokenRequest = performTokenRequest
        self.timeout = timeout
        self.now = now
    }

    func transferToken(resource: URL) async throws -> String? {
        guard resource.scheme == "https", let host = resource.host, !host.isEmpty else { return nil }
        let origin = "https://\(host.lowercased()):\(resource.port ?? 443)"
        return try await requestTransferToken(origin: origin, resource: resource.absoluteString)
    }

    private func requestTransferToken(origin: String, resource: String) async throws -> String? {
        guard let client = client() else { return nil }
        guard (originsWithoutLogin[origin] ?? .distantPast) <= now() else { return nil }

        do {
            return try await exchangeWithTimeout(
                clientId: client.clientId,
                clientSecret: client.clientSecret,
                resource: resource
            )
        } catch where Self.isInvalidTarget(error) {
            originsWithoutLogin[origin] = now().addingTimeInterval(Self.originWithoutLoginTTL)
            return nil
        }
    }

    private func exchangeWithTimeout(
        clientId: String,
        clientSecret: String?,
        resource: String
    ) async throws -> String? {
        let timeout = self.timeout
        return try await withCheckedThrowingContinuation { continuation in
            let result = FirstResult(continuation)
            result.race(
                Task {
                    do {
                        let token = try await self.exchange(clientId: clientId, clientSecret: clientSecret, resource: resource)
                        result.resume(with: .success(token))
                    } catch {
                        result.resume(with: .failure(error))
                    }
                },
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    result.resume(with: .success(nil))
                }
            )
        }
    }

    private func exchange(clientId: String, clientSecret: String?, resource: String) async throws -> String? {
        guard let accessToken = try await freshAccessToken() else { return nil }
        let request = OIDTokenRequest(
            configuration: try await serviceConfiguration(),
            grantType: Self.tokenExchangeGrantType,
            authorizationCode: nil,
            redirectURL: nil,
            clientID: clientId,
            clientSecret: clientSecret,
            scopes: [Self.scope],
            refreshToken: nil,
            codeVerifier: nil,
            additionalParameters: [
                "subject_token": accessToken,
                "subject_token_type": Self.accessTokenType,
                "requested_token_type": Self.sessionTransferTokenType,
                "resource": resource
            ]
        )
        guard
            let response = try await performTokenRequest(request),
            response.additionalParameters?["issued_token_type"] as? String == Self.sessionTransferTokenType
        else { return nil }
        return response.accessToken
    }

    private static func isInvalidTarget(_ error: Error) -> Bool {
        let response = (error as NSError).userInfo[OIDOAuthErrorResponseErrorKey] as? [String: Any]
        return response?[OIDOAuthErrorFieldError] as? String == invalidTarget
    }
}

@MainActor
private final class FirstResult {
    private var continuation: CheckedContinuation<String?, Error>?
    private var tasks: [Task<Void, Never>] = []

    init(_ continuation: CheckedContinuation<String?, Error>) {
        self.continuation = continuation
    }

    func race(_ tasks: Task<Void, Never>...) {
        self.tasks = tasks
    }

    func resume(with result: Result<String?, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
        tasks.forEach { $0.cancel() }
    }
}
