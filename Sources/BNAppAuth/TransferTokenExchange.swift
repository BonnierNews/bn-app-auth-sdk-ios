import AppAuth
import Foundation

/// Exchanges the user's access token for short-lived transfer tokens that log the user in on other sites.
/// Kept apart from BNAppAuth, which owns the user's tokens and only lends out a fresh access token.
/// Runs on the main actor, which keeps targetsWithoutLogin to a single thread.
@MainActor
final class TransferTokenExchange {
    nonisolated static let tokenExchangeGrantType = "urn:ietf:params:oauth:grant-type:token-exchange"
    nonisolated static let accessTokenType = "urn:ietf:params:oauth:token-type:access_token"
    // id-service requires a scope. Only openid, since the token is for another client than the app.
    nonisolated static let scope = OIDScopeOpenID
    nonisolated static let invalidTarget = "invalid_target"
    nonisolated static let timeout: TimeInterval = 2
    nonisolated static let targetWithoutLoginTTL: TimeInterval = 24 * 60 * 60

    private let client: @MainActor () -> BNAppAuth.ClientConfiguration?
    private let freshAccessToken: @MainActor () async throws -> String?
    private let serviceConfiguration: @MainActor () async throws -> OIDServiceConfiguration
    private let performTokenRequest: @MainActor (OIDTokenRequest) async throws -> String?
    private let timeout: TimeInterval
    private let now: @MainActor () -> Date

    private var targetsWithoutLogin: [String: Date] = [:]

    nonisolated init(
        client: @escaping @MainActor () -> BNAppAuth.ClientConfiguration?,
        freshAccessToken: @escaping @MainActor () async throws -> String?,
        serviceConfiguration: @escaping @MainActor () async throws -> OIDServiceConfiguration,
        performTokenRequest: @escaping @MainActor (OIDTokenRequest) async throws -> String?,
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

    func transferToken(audience: String) async throws -> String? {
        try await requestTransferToken(targetKey: audience, target: ["audience": audience])
    }

    func transferToken(resource: URL) async throws -> String? {
        // The token ends up in the url the browser opens, so it is never added to anything but https.
        guard resource.scheme == "https", let host = resource.host else { return nil }
        return try await requestTransferToken(targetKey: host, target: ["resource": resource.absoluteString])
    }

    private func requestTransferToken(targetKey: String, target: [String: String]) async throws -> String? {
        guard let client = client() else { return nil }
        guard (targetsWithoutLogin[targetKey] ?? .distantPast) <= now() else { return nil }

        do {
            return try await exchangeWithTimeout(
                clientId: client.clientId,
                clientSecret: client.clientSecret,
                target: target
            )
        } catch where Self.isInvalidTarget(error) {
            targetsWithoutLogin[targetKey] = now().addingTimeInterval(Self.targetWithoutLoginTTL)
            return nil
        }
    }

    // Returns nil once the timeout has passed, even if the exchange is still waiting for id-service.
    private func exchangeWithTimeout(
        clientId: String,
        clientSecret: String?,
        target: [String: String]
    ) async throws -> String? {
        let timeout = self.timeout
        return try await withCheckedThrowingContinuation { continuation in
            let result = FirstResult(continuation)
            result.race(
                Task {
                    do {
                        let token = try await self.exchange(clientId: clientId, clientSecret: clientSecret, target: target)
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

    private func exchange(clientId: String, clientSecret: String?, target: [String: String]) async throws -> String? {
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
                "subject_token_type": Self.accessTokenType
            ].merging(target) { _, targetValue in targetValue }
        )
        return try await performTokenRequest(request)
    }

    private static func isInvalidTarget(_ error: Error) -> Bool {
        let response = (error as NSError).userInfo[OIDOAuthErrorResponseErrorKey] as? [String: Any]
        return response?[OIDOAuthErrorFieldError] as? String == invalidTarget
    }
}

// Resumes the continuation with whichever task finishes first, and cancels the others.
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
