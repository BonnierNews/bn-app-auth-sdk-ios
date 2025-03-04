import Foundation

public extension BNAppAuth {
    struct TokenResponse {
        public let idToken: String
        public let isUpdated: Bool
        
        public init(idToken: String, isUpdated: Bool) {
            self.idToken = idToken
            self.isUpdated = isUpdated
        }
    }
}
