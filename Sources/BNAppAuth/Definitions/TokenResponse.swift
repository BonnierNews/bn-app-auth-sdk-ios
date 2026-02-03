import Foundation

public extension BNAppAuth {
    struct TokenResponse {
        public let idToken: String
        public let bnIdToken: String?
        public let isUpdated: Bool
        public let loginToken: String?
        
        public init(idToken: String, bnIdToken: String? = nil, isUpdated: Bool, loginToken: String? = nil) {
            self.idToken = idToken
            self.bnIdToken = bnIdToken
            self.isUpdated = isUpdated
            self.loginToken = loginToken
        }
    }
}
