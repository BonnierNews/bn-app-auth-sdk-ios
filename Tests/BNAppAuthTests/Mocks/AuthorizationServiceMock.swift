import AppAuth
@testable import BNAppAuth

class AuthorizationServiceMock: TestableOIDAuthorizationService {
    static var configurationReturnValue = OIDServiceConfiguration(
        authorizationEndpoint: URL(string: "https://issuer/authorization")!,
        tokenEndpoint: URL(string: "https://issuer/authorization")!,
        issuer: URL(string: "https://issuer")!,
        registrationEndpoint: URL(string: "https://issuer/register")!,
        endSessionEndpoint: URL(string: "https://issuer/session/end")!
    )
    static var discoverConfigurationInvokeCount = 0
    static var discoverConfigurationErrorReturnValue: Error?
    static var discoverConfigurationWasCalled: (@Sendable () -> Void)?
    
    static var performWasCalled: (@Sendable (OIDTokenRequest) -> Void)?
    static var performStub: (@Sendable (OIDTokenRequest, @escaping OIDTokenCallback) -> Void)?
    static var performResponseReturnValue: OIDTokenResponse?
    static var performErrorReturnValue: Error?

    static func discoverConfiguration(forIssuer issuerURL: URL, completion: @escaping @Sendable OIDDiscoveryCallback) {
        discoverConfigurationInvokeCount += 1
        if let discoverConfigurationErrorReturnValue {
            completion(nil,discoverConfigurationErrorReturnValue)
        } else {
            completion(configurationReturnValue,nil)
        }
        discoverConfigurationWasCalled?()
    }
    
    static func perform(_ request: OIDTokenRequest, callback: @escaping @Sendable OIDTokenCallback) {
        performWasCalled?(request)
        if let performStub = performStub {
            performStub(request, callback)
            return
        }
        callback(performResponseReturnValue, performErrorReturnValue)
    }
    
    static func reset() {
        Self.discoverConfigurationInvokeCount = 0
        Self.discoverConfigurationWasCalled = nil
        Self.discoverConfigurationErrorReturnValue = nil
        
        Self.performWasCalled = nil
        Self.performStub = nil
        Self.performResponseReturnValue = nil
        Self.performErrorReturnValue = nil
    }
}

