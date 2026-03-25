import AppAuth
import UIKit



public class BNAppAuth: NSObject {
    public static let shared = BNAppAuth()

    public weak var delegate: UIViewController?

    private let authStorage: AuthStoraging
    private let authService: TestableOIDAuthorizationService.Type

    private var client: ClientConfiguration?
    private let authFlowBuilder: AuthorizationFlowBuilding
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?
    private let userDefaults: UserDefaults

    private let isolationQueue = DispatchQueue(label: "se.bonniernews.bnappauth.isolation")
    private let tokenMutex = NSLock()
    private var isMigrationDone = false

    private var needsMigration: Bool {
        get {
            guard client?.useMigration == true else { return false }
            let isCompleted = userDefaults.bool(forKey: UserDefaultsKeys.BnMigrationCompleted.rawValue)
            return !isCompleted
        }
        set {
            userDefaults.set(!newValue, forKey: UserDefaultsKeys.BnMigrationCompleted.rawValue)
        }
    }

    public init(
        authStorage: AuthStoraging? = nil,
        authService: TestableOIDAuthorizationService.Type = OIDAuthorizationService.self,
        authFlowBuilder: AuthorizationFlowBuilding? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.authStorage = authStorage ?? defaultAuthStorage()
        self.authService = authService
        self.authFlowBuilder = authFlowBuilder ?? defaultAuthorizationFlowBuilder()
        self.userDefaults = userDefaults
    }

    private lazy var authState: OIDAuthState? = {
        if let state = authStorage.getStoredState() {
            state.stateChangeDelegate = self
            currentToken = state.lastTokenResponse?.idToken
            return state
        }
        return nil
    }() {
        didSet {
            if let authState {
                authState.stateChangeDelegate = self
                currentToken = authState.lastTokenResponse?.idToken
                authStorage.store(authState)
                onStateChangeListeners.forEach { listener in
                    listener(authState.isAuthorized)
                }
            } else {
                currentToken = nil
                authStorage.delete()
                onStateChangeListeners.forEach { listener in
                    listener(false)
                }
            }
        }
    }

    private var currentToken: String?

    private func setAuthState(_ state: OIDAuthState?) {
        authState = state
    }

    public func configure(client: ClientConfiguration) {
        self.client = client
    }

    public var isAuthorized: Bool {
        authState?.isAuthorized == true
    }

    public func createAccount(locale: String? = nil, completion: ((Result<Void,Error>) -> Void)?) {
        login(action: "create-user", locale: locale, completion: completion)
    }

    public func login(
        token: String? = nil,
        action: String? = nil,
        locale: String? = nil,
        completion: ((Result<Void,Error>) -> Void)?)
    {
        guard let client, let delegate else {
            completion?(.failure(BNAppAuthError.clientNotConfigured))
            return
        }
        if client.useMigration {
            needsMigration = false
        }
        let clientId = client.clientId
        let clientSecret = client.clientSecret
        let clientLoginRedirectUrl = client.loginRedirectURL
        let customScopes = client.customScopes ?? []

        authService.discoverConfiguration(
            forIssuer: client.issuer
        ) { [weak self] configuration, error in
            guard let configuration = configuration else {
                Logger.authentication.error("Error retrieving discovery document: %@", error?.localizedDescription ?? "Unknown error")
                completion?(.failure(BNAppAuthError.oidcConfigurationNotFound))
                return
            }

            var additionalParameters = [
                "prompt": client.prompt
            ]

            if let token = token {
                additionalParameters["token"] = token
            }

            if let action {
                additionalParameters["action"] = action
            }

            if let locale {
                additionalParameters["ui_locales"] = locale
            }

            let request = OIDAuthorizationRequest(
                configuration: configuration,
                clientId: clientId,
                clientSecret: clientSecret,
                scopes: [OIDScopeOpenID] + customScopes,
                redirectURL: clientLoginRedirectUrl,
                responseType: OIDResponseTypeCode,
                additionalParameters: additionalParameters
            )

            Logger.authentication.info("Initiating authorization request with scope: %@", request.scope ?? "nil")

            let authenticationCallback: OIDAuthStateAuthorizationCallback = { authState, error in
                if let authState = authState {
                    self?.setAuthState(authState)
                    Logger.authentication.debug("Authorization succeded with token response: %@", authState.lastTokenResponse ?? "nil")
                    completion?(.success)
                } else {
                    Logger.authentication.error("Authorization failed with error: %@", error?.localizedDescription ?? "Unknown error")
                    self?.setAuthState(nil)
                    completion?(.failure(error ?? BNAppAuthError.oidcCallbackFailedWithUnknownError))
                }
            }

            if client.useCustomBrowser {
                self?.currentAuthorizationFlow = self?.authFlowBuilder.customBrowserAuthorizationFlow(request: request, completion: authenticationCallback)
            } else {
                self?.currentAuthorizationFlow = self?.authFlowBuilder.defaultAuthorizationFlow(request: request, viewController: delegate, completion: authenticationCallback)
            }
        }
    }

    private func isUserCancelled(error: Error) -> Bool {
        [
            OIDErrorCode.userCanceledAuthorizationFlow.rawValue,
            OIDErrorCode.programCanceledAuthorizationFlow.rawValue
        ].contains((error as NSError).code)
    }

    public func logout(completion: ((Result<Void,Error>) -> Void)?) {
        guard let client, let delegate else {
            completion?(.failure(BNAppAuthError.clientNotConfigured))
            return
        }

        let clientId = client.clientId
        let clientLogoutRedirectUrl = client.logoutRedirectUrl

        authService.discoverConfiguration(
            forIssuer: client.issuer
        ) { [weak self] configuration, error in
            guard let configuration = configuration else {
                Logger.authentication.error("Error retrieving discovery document: %@", error?.localizedDescription ?? "Unknown error")
                completion?(.failure(BNAppAuthError.oidcConfigurationNotFound))
                return
            }

            let logoutRequest = OIDEndSessionRequest(
                configuration: configuration,
                idTokenHint: "",
                postLogoutRedirectURL: clientLogoutRedirectUrl,
                additionalParameters: [
                    "client_id": clientId
                ]
            )
            let endSessionCallback: OIDEndSessionCallback = { [weak self] authorizationState, error in
                let successCompletion = {
                    self?.setAuthState(nil)
                    completion?(.success)
                }

                switch error {
                case .some(let error):
                    if self?.isUserCancelled(error: error) == true {
                        completion?(.failure(error))
                    } else {
                        successCompletion()
                    }
                case .none:
                    successCompletion()
                }
            }

            do {
                self?.currentAuthorizationFlow = try self?.authFlowBuilder.defaultEndSessionFlow(request: logoutRequest, viewController: delegate, completion: endSessionCallback)
            } catch {
                Logger.authentication.error("Logout failed with error: %@", error.localizedDescription)
                completion?(.failure(error))
            }
        }
    }

    public func continueAuthorization(_ url: URL) -> Bool {
        if
            let authorizationFlow = self.currentAuthorizationFlow,
            authorizationFlow.resumeExternalUserAgentFlow(with: url)
        {
            self.currentAuthorizationFlow = nil
            return true
        }
        return false
    }

    public func getIdToken(
        forceRefresh: Bool = false,
        getLoginToken: Bool = false,
        completion: @escaping (Result<TokenResponse?, Error>) -> Void
    ) {
        isolationQueue.async { [weak self] in
            guard let self = self else { return }

            self.tokenMutex.lock()
            defer { self.tokenMutex.unlock() }

            guard let client = self.client, let _ = self.authState else {
                completion(.success(nil))
                return
            }

            // Migration check — same dual-flag pattern as Android (isMigrationDone in-memory + needsMigration persistent)
            let migrationNeeded = !self.isMigrationDone && self.needsMigration
            if migrationNeeded, let currentToken = self.currentToken {
                // Set flags BEFORE exchange to prevent infinite retry loops on failure (matches Android)
                self.needsMigration = false
                self.isMigrationDone = true

                let success = self.performSilentExchangeSync(oldIdToken: currentToken)
                if !success {
                    self.clearState()
                    completion(.failure(BNAppAuthError.oidcCallbackFailedWithUnknownError))
                    return
                }

                // The exchange just produced fresh tokens — return them directly without an
                // additional refresh round-trip (the exchanged token is already up-to-date).
                guard let exchangedToken = self.currentToken else {
                    completion(.success(nil))
                    return
                }
                let bnIdToken = (client.customScopes?.contains("old_bnidtoken") == true)
                    ? (self.authState?.lastTokenResponse?.additionalParameters?["old_bnidtoken"] as? String)
                    : nil
                let tokenResponse = TokenResponse(
                    idToken: exchangedToken,
                    bnIdToken: bnIdToken,
                    isUpdated: true,
                    loginToken: nil
                )
                completion(.success(tokenResponse))
                return
            }

            guard let currentAuthState = self.authState else {
                completion(.success(nil))
                return
            }

            // Early return — same as Android lines 252–263:
            // If the token is still fresh, return it directly from our own state without
            // asking AppAuth to perform a (potentially network) refresh.
            if !forceRefresh && !getLoginToken && self.isAuthorized && !self.tokenNeedsRefresh(currentAuthState) {
                let params = currentAuthState.lastTokenResponse?.additionalParameters
                let bnIdToken = (client.customScopes?.contains("old_bnidtoken") == true)
                    ? (params?["old_bnidtoken"] as? String)
                    : nil
                let loginToken = params?["login_token"] as? String
                if let idToken = self.currentToken {
                    completion(.success(TokenResponse(idToken: idToken, bnIdToken: bnIdToken, isUpdated: false, loginToken: loginToken)))
                    return
                }
            }

            if !self.isAuthorized {
                completion(.success(nil))
                return
            }

            // Hold the mutex open until the AppAuth callback fires, matching Android's CompletableDeferred pattern
            let sema = DispatchSemaphore(value: 0)
            self.performTokenRefresh(
                client: client,
                authState: currentAuthState,
                forceRefresh: forceRefresh,
                getLoginToken: getLoginToken
            ) { result in
                completion(result)
                sema.signal()
            }
            sema.wait()
        }
    }

    // Mirrors Android's `authState?.needsTokenRefresh == false` check.
    // AppAuth-iOS uses the same 60-second tolerance internally (kExpiryTimeTolerance = 60).
    private func tokenNeedsRefresh(_ authState: OIDAuthState) -> Bool {
        guard let expirationDate = authState.lastTokenResponse?.accessTokenExpirationDate else {
            return true
        }
        return expirationDate.timeIntervalSinceNow <= 60
    }

    // Synchronous wrapper for exchangeIdToken — blocks the calling thread via semaphore
    // until the async exchange completes. Must only be called from the isolation queue.
    private func performSilentExchangeSync(oldIdToken: String) -> Bool {
        guard let client = client else { return false }

        // appendingPathComponent without a leading slash correctly appends to any issuer path
        let exchangeEndpoint = client.issuer.appendingPathComponent("token")

        var success = false
        let sema = DispatchSemaphore(value: 0)
        exchangeIdToken(oldIdToken: oldIdToken, newExchangeEndpoint: exchangeEndpoint) { result in
            switch result {
            case .success(let token):
                success = token != nil
            case .failure:
                success = false
            }
            sema.signal()
        }
        sema.wait()
        return success
    }

    private func performTokenRefresh(
        client: ClientConfiguration,
        authState: OIDAuthState,
        forceRefresh: Bool,
        getLoginToken: Bool,
        completion: @escaping (Result<TokenResponse?,Error>) -> Void
    ) {
        var refreshParams: [String: String] = [:]

        if forceRefresh || getLoginToken {
            authState.setNeedsTokenRefresh()
        }
        if forceRefresh {
            refreshParams["bypass_cache"] = "true"
        }
        if getLoginToken {
            refreshParams["issue_login_token"] = "true"
        }

        authState.performAction(
            freshTokens: { [weak self] _, idToken, error in
                let bnIdToken = (client.customScopes?.contains("old_bnidtoken") == true)
                    ? (authState.lastTokenResponse?.additionalParameters?["old_bnidtoken"] as? String)
                    : nil
                let loginToken = getLoginToken
                    ? (authState.lastTokenResponse?.additionalParameters?["login_token"] as? String)
                    : nil
                switch error {
                case .some(let error):
                    // Match Android: propagate all errors without clearing auth state
                    Logger.authentication.error("Token refresh failed: %@", error.localizedDescription)
                    completion(.failure(error))
                case .none:
                    if let idToken {
                        let tokenResponse = TokenResponse(
                            idToken: idToken,
                            bnIdToken: bnIdToken,
                            isUpdated: idToken != self?.currentToken,
                            loginToken: loginToken
                        )
                        completion(.success(tokenResponse))
                        self?.currentToken = idToken
                    } else {
                        completion(.success(nil))
                    }
                }
            },
            additionalRefreshParameters: refreshParams
        )
    }

    public func exchangeIdToken(
        oldIdToken: String,
        newExchangeEndpoint: URL,
        completion: @escaping (Result<String?,Error>) -> Void
    ) {
        guard let client = client else {
            completion(.success(nil))
            return
        }
        let customScopes = client.customScopes ?? []

        authService.discoverConfiguration(forIssuer: client.issuer) { [weak self] serviceConfiguration, error in
            guard let self = self else { return }

            if let error = error {
                Logger.authentication.error("Error retrieving discovery document: %@", error.localizedDescription)
                completion(.failure(error))
                return
            }

            guard let serviceConfiguration = serviceConfiguration else {
                Logger.authentication.error("Failed getting  serviceConfiguration")
                completion(.success(nil))
                return
            }

            // 1. Create a config pointing to the NEW exchange endpoint
            let customConfig = OIDServiceConfiguration(
                authorizationEndpoint: serviceConfiguration.authorizationEndpoint,
                tokenEndpoint: newExchangeEndpoint
            )

            // 2. Build the request with Scopes
            let additionalParams = [
                "subject_token": oldIdToken,
                "subject_token_type": "urn:ietf:params:oauth:token-type:id_token"
            ]

            let tokenRequest = OIDTokenRequest(
                configuration: customConfig,
                grantType: "urn:ietf:params:oauth:grant-type:token-exchange",
                authorizationCode: nil,
                redirectURL: nil,
                clientID: client.clientId,
                clientSecret: client.clientSecret,
                scopes: [OIDScopeOpenID] + customScopes,
                refreshToken: nil,
                codeVerifier: nil,
                additionalParameters: additionalParams
            )

            // 3. Perform the token request
            self.authService.perform(tokenRequest) { [weak self] tokenResponse, error in
                guard let self = self else { return }

                if let error = error {
                    Logger.authentication.error("Token exchange failed: %@", error.localizedDescription)
                    completion(.failure(error))
                    return
                }

                guard let tokenResponse = tokenResponse else {
                    completion(.success(nil))
                    return
                }

                // 4. TRANSITION TO ORDINARY FLOW
                // Build a synthetic authorization response using the STANDARD serviceConfiguration
                // so that AppAuth has redirect_uri and client_id available for future token refreshes.
                let authRequest = OIDAuthorizationRequest(
                    configuration: serviceConfiguration,
                    clientId: client.clientId,
                    clientSecret: client.clientSecret,
                    scopes: [OIDScopeOpenID] + customScopes,
                    redirectURL: client.loginRedirectURL,
                    responseType: OIDResponseTypeCode,
                    additionalParameters: nil
                )
                let authResponse = OIDAuthorizationResponse(
                    request: authRequest,
                    parameters: [:]
                )
                let ordinaryState = OIDAuthState(
                    authorizationResponse: authResponse,
                    tokenResponse: tokenResponse
                )

                self.setAuthState(ordinaryState)
                authState?.update(with: tokenResponse, error: nil)
                completion(.success(self.currentToken))
            }
        }
    }


    public func clearState() {
        setAuthState(nil)
    }

    /// Releases SDK resources. Provided for API parity with Android; on iOS AppAuth manages its own lifecycle.
    public func releaseResources() {}

    public typealias StateChangeListener = (Bool) -> Void
    private var onStateChangeListeners: [StateChangeListener] = []
    public func addOnStateChangeListener(_ listener: @escaping StateChangeListener) {
        onStateChangeListeners.append(listener)
    }
}

extension BNAppAuth: OIDAuthStateChangeDelegate {
    public func didChange(_ state: OIDAuthState) {
        authStorage.store(state)
        onStateChangeListeners.forEach { listener in
            listener(state.isAuthorized)
        }
    }
}

private extension Logger {
    static let authentication = Category("authentication")
}

private extension Result where Success == Void {
    static var success: Result {
        return .success(())
    }
}
