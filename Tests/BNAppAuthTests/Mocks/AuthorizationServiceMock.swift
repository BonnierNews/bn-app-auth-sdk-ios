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
    static var discoverConfigurationWasCalled: (() -> Void)?
    static func discoverConfiguration(forIssuer issuerURL: URL, completion: @escaping OIDDiscoveryCallback) {
        discoverConfigurationInvokeCount += 1
        if let discoverConfigurationErrorReturnValue {
            completion(nil,discoverConfigurationErrorReturnValue)
        } else {
            completion(configurationReturnValue,nil)
        }
        discoverConfigurationWasCalled?()
    }
    
    static func reset() {
        Self.discoverConfigurationInvokeCount = 0
        Self.discoverConfigurationWasCalled = nil
        Self.discoverConfigurationErrorReturnValue = nil
    }
}
