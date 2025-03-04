import AppAuth
import Foundation

public typealias AuthorizationFlowBuilderCallback = (OIDAuthorizationRequest, UIViewController, @escaping OIDAuthStateAuthorizationCallback) -> OIDExternalUserAgentSession
public typealias EndSessionFlowBuilder = (OIDEndSessionRequest, UIViewController, @escaping OIDEndSessionCallback) throws -> OIDExternalUserAgentSession

let defaultAuthStorage: () -> AuthStoraging = { AuthStorage() }
let defaultAuthorizationFlowBuilder: () -> AuthorizationFlowBuilding = { AuthorizationFlowBuilder() }

public protocol AuthorizationFlowBuilding {
    func defaultAuthorizationFlow(request: OIDAuthorizationRequest, viewController: UIViewController, completion: @escaping OIDAuthStateAuthorizationCallback) -> OIDExternalUserAgentSession
    func customBrowserAuthorizationFlow(request: OIDAuthorizationRequest, completion: @escaping OIDAuthStateAuthorizationCallback) -> OIDExternalUserAgentSession
    func defaultEndSessionFlow(request: OIDEndSessionRequest, viewController: UIViewController, completion: @escaping OIDEndSessionCallback) throws -> OIDExternalUserAgentSession
}

internal class AuthorizationFlowBuilder: AuthorizationFlowBuilding {
    func defaultAuthorizationFlow(request: OIDAuthorizationRequest, viewController: UIViewController, completion: @escaping OIDAuthStateAuthorizationCallback) -> OIDExternalUserAgentSession {
        OIDAuthState.authState(
            byPresenting: request,
            presenting: viewController,
            callback: completion
        )
    }
    
    func customBrowserAuthorizationFlow(request: OIDAuthorizationRequest, completion: @escaping OIDAuthStateAuthorizationCallback) -> OIDExternalUserAgentSession {
        OIDAuthState.authState(
            byPresenting: request,
            externalUserAgent: OIDExternalUserAgentIOSCustomBrowser.customBrowserSafari(),
            callback: completion
        )
    }
    
    func defaultEndSessionFlow(request: OIDEndSessionRequest, viewController: UIViewController, completion: @escaping OIDEndSessionCallback) throws -> OIDExternalUserAgentSession {
        guard let userAgent = OIDExternalUserAgentIOS(presenting: viewController) else { throw BNAppAuthError.couldNotCreateUserAgent }
        return OIDAuthorizationService.present(
            request,
            externalUserAgent: userAgent,
            callback: completion
        )
    }
}

public let defaultEndSessionFlowBuilder: EndSessionFlowBuilder = { request, vc, callback in
    guard let userAgent = OIDExternalUserAgentIOS(presenting: vc) else { throw BNAppAuthError.couldNotCreateUserAgent }
    return OIDAuthorizationService.present(
        request,
        externalUserAgent: userAgent,
        callback: callback
    )
}
