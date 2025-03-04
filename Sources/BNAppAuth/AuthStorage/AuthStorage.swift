import AppAuth
import Foundation

public protocol AuthStoraging {
    func getStoredState<T: OIDAuthState>() -> T?
    func store<T: OIDAuthState>(_ state: T)
    func delete()
}

internal class AuthStorage: AuthStoraging {
    private let defaultKeychain: () -> KeychainWrapping = { KeychainWrapper() }
    private let keychain: KeychainWrapping
    
    init(keychain: KeychainWrapping? = nil) {
        self.keychain = keychain ?? defaultKeychain()
    }
    
    
    public func getStoredState<T: OIDAuthState>() -> T? {
        if let authStateData = keychain.data(forKey: Constants.keychainAuthStateKey) {
            let state = try? NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: authStateData)
            return state
        }
        return nil
    }
    
    public func store<T: OIDAuthState>(_ state: T) {
        if let stateData = try? NSKeyedArchiver.archivedData(withRootObject: state, requiringSecureCoding: false) {
            keychain.set(stateData, forKey: Constants.keychainAuthStateKey)
        }
    }
    
    public func delete() {
        keychain.delete(forKey: Constants.keychainAuthStateKey)
    }
}
