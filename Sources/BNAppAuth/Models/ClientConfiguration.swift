import Foundation

extension BNAppAuth {
    public struct ClientConfiguration {
        let issuer: URL
        let clientId: String
        let clientSecret: String?
        let prompt: String
        let loginRedirectURL: URL
        let logoutRedirectUrl: URL
        let useCustomBrowser: Bool
        let isDebuggable: Bool
        
        public init(
            issuer: URL,
            clientId: String,
            clientSecret: String? = nil,
            prompt: String = "select_account consent",
            loginRedirectURL: URL,
            logoutRedirectUrl: URL,
            useCustomBrowser: Bool = false,
            isDebuggable: Bool = false
        ) {
            self.issuer = issuer
            self.clientId = clientId
            self.clientSecret = clientSecret
            self.prompt = prompt
            self.loginRedirectURL = loginRedirectURL
            self.logoutRedirectUrl = logoutRedirectUrl
            self.useCustomBrowser = useCustomBrowser
            self.isDebuggable = isDebuggable
        }
    }
}
