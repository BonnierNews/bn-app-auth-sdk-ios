import Foundation
import Security

public protocol KeychainWrapping {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    func delete(forKey key: String)
}

internal class KeychainWrapper: KeychainWrapping {
    
    typealias Add = (_: CFDictionary, _: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    typealias Copy = (_: CFDictionary, _: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    typealias Delete = (_: CFDictionary) -> OSStatus
    
    let addFunction: Add
    let copyFunction: Copy
    let deleteFunction: Delete
    
    init(
        addFunction: @escaping Add = Security.SecItemAdd,
        copyFunction: @escaping Copy = Security.SecItemCopyMatching,
        deleteFunction: @escaping Delete = Security.SecItemDelete
    ) {
        self.addFunction = addFunction
        self.copyFunction = copyFunction
        self.deleteFunction = deleteFunction
    }
    
    func data(forKey key: String) -> Data? {
        if let retrievedData = loadDataFromKeychain(forKey: key) {
            Logger.keychain.debug("Successfully retrieved keychain data for key: %@", key)
            return retrievedData
        } else {
            return nil
        }
    }
    
    func set(_ data: Data, forKey key: String) {
        if saveDataToKeychain(data: data, forKey: key) {
            Logger.keychain.debug("Successfully stored keychain data for key: %@", key)
        }
    }
    
    func delete(forKey key: String) {
        if deleteDataFromKeychain(forKey: key) {
            Logger.keychain.debug("Successfully deleted keychain data for key: %@", key)
        }
    }
    
    private func saveDataToKeychain(data: Data, forKey key: String) -> Bool {
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let _ = deleteFunction(keychainQuery as CFDictionary)
        
        let status = addFunction(keychainQuery as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.keychain.debug("Failed to save keychain data for key: %@, with error: %@", key, status.description)
        }
        return status == errSecSuccess
    }
    
    private func deleteDataFromKeychain(forKey key: String) -> Bool {
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = deleteFunction(keychainQuery as CFDictionary)
        if status != errSecSuccess {
            Logger.keychain.debug("Failed to delete keychain data for key: %@, with error: %@", key, status.description)
        }
        return status == errSecSuccess
    }
    
    private func loadDataFromKeychain(forKey key: String) -> Data? {
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: kCFBooleanTrue!
        ]
        
        var retrievedData: AnyObject?
        
        let status = copyFunction(keychainQuery as CFDictionary, &retrievedData)
        
        if status == errSecSuccess, let data = retrievedData as? Data {
            return data
        } else {
            Logger.keychain.debug("Failed to retrieve keychain data for key: %@, with error: %@", key, status.description)
            return nil
        }
    }
}

private extension Logger {
    static let keychain = Category("keychain")
}
