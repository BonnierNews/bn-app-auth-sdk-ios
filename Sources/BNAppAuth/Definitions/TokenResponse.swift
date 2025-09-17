import Foundation

public extension BNAppAuth {
    struct TokenResponse {
        public let idToken: String
        public let bnIdToken: String?
        public let isUpdated: Bool
        
        public init(idToken: String, bnIdToken: String? = nil, isUpdated: Bool) {
            self.idToken = idToken
            self.bnIdToken = bnIdToken
            self.isUpdated = isUpdated
        }
    }
}
