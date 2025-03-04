import AppAuth
@testable import BNAppAuth

class AuthorizationFlowBuilderMock: AuthorizationFlowBuilding {
    var defaultAuthorizationFlowInvokeCount = 0
    var defaultAuthorizationFlowWasCalledTimes: ((Int) -> Void)?
    
    var defaultAuthorizationFlowLastRequest: OIDAuthorizationRequest?
    var defaultAuthorizationFlowLastViewController: UIViewController?
    var defaultAuthorizationFlowLastCompletion: OIDAuthStateAuthorizationCallback?
    func defaultAuthorizationFlow(request: OIDAuthorizationRequest, viewController: UIViewController, completion: @escaping OIDAuthStateAuthorizationCallback) -> OIDExternalUserAgentSession {
        
        defaultAuthorizationFlowLastRequest = request
        defaultAuthorizationFlowLastViewController = viewController
        defaultAuthorizationFlowLastCompletion = completion
        
        defaultAuthorizationFlowInvokeCount += 1
        defaultAuthorizationFlowWasCalledTimes?(defaultAuthorizationFlowInvokeCount)
        
        return OIDAuthState.authState(byPresenting: request, presenting: viewController, callback: completion)
    }
    
    var customBrowserAuthorizationFlowInvokeCount = 0
    var customBrowserAuthorizationFlowWasCalled: ((Int) -> Void)?
    var customBrowserAuthorizationFlowLastRequest: OIDAuthorizationRequest?
    var customBrowserAuthorizationFlowLastCompletion: OIDAuthStateAuthorizationCallback?
    func customBrowserAuthorizationFlow(request: OIDAuthorizationRequest, completion: @escaping OIDAuthStateAuthorizationCallback) -> OIDExternalUserAgentSession {
        
        customBrowserAuthorizationFlowLastRequest = request
        customBrowserAuthorizationFlowLastCompletion = completion
        
        customBrowserAuthorizationFlowInvokeCount += 1
        customBrowserAuthorizationFlowWasCalled?(customBrowserAuthorizationFlowInvokeCount)
        
        return OIDAuthState.authState(byPresenting: request, externalUserAgent: OIDExternalUserAgentIOSCustomBrowser.customBrowserSafari(), callback: completion)
    }
    
    var defaultEndSessionFlowBuilderInvokeCount = 0
    var defaultEndSessionFlowWasCalledTimes: ((Int) -> Void)?
    var defaultEndSessionFlowLastRequest: OIDEndSessionRequest?
    var defaultEndSessionFlowLastViewController: UIViewController?
    var defaultEndSessionFlowLastCompletion: OIDEndSessionCallback?
    func defaultEndSessionFlow(request: OIDEndSessionRequest, viewController: UIViewController, completion: @escaping OIDEndSessionCallback) throws -> OIDExternalUserAgentSession {
        
        defaultEndSessionFlowLastRequest = request
        defaultEndSessionFlowLastViewController = viewController
        defaultEndSessionFlowLastCompletion = completion
        
        defaultEndSessionFlowBuilderInvokeCount += 1
        defaultEndSessionFlowWasCalledTimes?(defaultEndSessionFlowBuilderInvokeCount)
        
        guard let userAgent = OIDExternalUserAgentIOS(presenting: viewController) else { throw BNAppAuthError.couldNotCreateUserAgent }
        return OIDAuthorizationService.present(
            request,
            externalUserAgent: userAgent,
            callback: completion
        )
    }
    
}

