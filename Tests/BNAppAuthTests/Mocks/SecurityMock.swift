import Foundation
class SecurityMock {
    var _secureStore: [String:[String: Any]] = [:]
    
    var SecItemAddReturnValue: OSStatus = errSecSuccess
    func SecItemAdd(_ cfDictionary: CFDictionary, _ pointer: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        if
            let dictionary = cfDictionary as? [String: Any],
            let key = dictionary[kSecAttrAccount as String] as? String
        {
            _secureStore[key] = dictionary
        }
        return SecItemAddReturnValue
    }
    
    var SecItemCopyMatchingReturnValue: OSStatus = errSecSuccess
    func SecItemCopyMatching(_ cfDictionary: CFDictionary, _ pointer: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        if
            let dictionary = cfDictionary as? [String: Any],
            let key = dictionary[kSecAttrAccount as String] as? String,
            let fetchedDictionary = _secureStore[key]
        {
            if let data = fetchedDictionary[kSecValueData as String] as? Data {
                pointer?.pointee = data as CFData
            }
        }
        return SecItemCopyMatchingReturnValue
    }
    
    var SecItemDeleteReturnValue: OSStatus = errSecSuccess
    func SecItemDelete(_ cfDictionary: CFDictionary) -> OSStatus {
        if
            let dictionary = cfDictionary as? [String: Any],
            let key = dictionary[kSecAttrAccount as String] as? String
        {
            _secureStore[key] = nil
        }
        return SecItemDeleteReturnValue
    }
}
