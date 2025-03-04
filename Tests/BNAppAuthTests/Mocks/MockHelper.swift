import AppAuth
@testable import BNAppAuth

enum MockHelper {
    static func authStateMock(refreshToken: String = "refreshToken") -> AuthStateMock {
        let tokenResponse = OIDTokenResponse(
            request: OIDTokenRequest(
                configuration: AuthorizationServiceMock.configurationReturnValue,
                grantType: "refresh",
                authorizationCode: nil,
                redirectURL: nil,
                clientID: "clientId",
                clientSecret: nil,
                scope: nil,
                refreshToken: refreshToken,
                codeVerifier: nil,
                additionalParameters: nil
            ),
            parameters: [:]
        )
        
        let state = AuthStateMock(
            authorizationResponse: OIDAuthorizationResponse(
                request: OIDAuthorizationRequest(
                    configuration: AuthorizationServiceMock.configurationReturnValue,
                    clientId: "clientId",
                    clientSecret: nil,
                    scope: nil,
                    redirectURL: nil,
                    responseType: "code",
                    state: nil,
                    nonce: nil,
                    codeVerifier: nil,
                    codeChallenge: nil,
                    codeChallengeMethod: nil,
                    additionalParameters: nil),
                parameters: [:]
            )
        )
        
        state.update(with: tokenResponse, error: nil)
        
        return state
    }
    
    static func clientConfiguration() -> BNAppAuth.ClientConfiguration {
        BNAppAuth.ClientConfiguration(
            issuer: URL(string: "https://oidc-server-url")!,
            clientId: "client-id",
            clientSecret: nil,
            loginRedirectURL: URL(string: "login-callback-url")!,
            logoutRedirectUrl: URL(string: "logout-callback-url")!
        )
    }
}
