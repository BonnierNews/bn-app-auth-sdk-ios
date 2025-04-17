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
    
    public init(
        authStorage: AuthStoraging? = nil,
        authService: TestableOIDAuthorizationService.Type = OIDAuthorizationService.self,
        authFlowBuilder: AuthorizationFlowBuilding? = nil
    ) {
        self.authStorage = authStorage ?? defaultAuthStorage()
        self.authService = authService
        self.authFlowBuilder = authFlowBuilder ?? defaultAuthorizationFlowBuilder()
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
    
    private func isRecoverable(error: Error) -> Bool {
        [
            OIDErrorCode.networkError.rawValue
        ].contains((error as NSError).code)
    }
    
    public func getIdToken(
        forceRefresh: Bool = false,
        completion: @escaping (Result<TokenResponse?,Error>) -> Void
    ) {
        guard let client, let authState else {
            completion(.success(nil))
            return
        }
        
        if forceRefresh {
            authState.setNeedsTokenRefresh()
        }
        
        authState.performAction(
            freshTokens: { [weak self] _, idToken, error in
                switch error {
                case .some(let error):
                    if self?.isRecoverable(error: error) == true {
                        if let currentToken = self?.currentToken {
                            let recoveredTokenResponse = TokenResponse(
                                idToken: currentToken,
                                isUpdated: false
                            )
                            completion(.success(recoveredTokenResponse))
                        } else {
                            completion(.success(nil))
                        }
                    } else {
                        self?.setAuthState(nil)
                        completion(.failure(error))
                    }
                case .none:
                    if let idToken {
                        let tokenResponse = TokenResponse(
                            idToken: idToken,
                            isUpdated: idToken != self?.currentToken
                        )
                        completion(.success(tokenResponse))
                        self?.currentToken = idToken
                    } else {
                        completion(.success(nil))
                    }
                }
            },
            additionalRefreshParameters: [
                "prompt": client.prompt
            ]
        )
    }

    public func clearState() {
        setAuthState(nil)
    }
    
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
