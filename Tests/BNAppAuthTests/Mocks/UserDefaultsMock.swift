import Foundation

class UserDefaultsMock: UserDefaults {

    var synchronizeInvoked: Bool = false

    var dictionaryStorage = [String : Any]()

    override func register(defaults registrationDictionary: [String : Any]) {

        for key in registrationDictionary.keys {
            if dictionaryStorage[key] == nil {
                dictionaryStorage[key] = registrationDictionary[key] as AnyObject?
            }
        }
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        dictionaryStorage[defaultName] = value
    }
    
    override func removeObject(forKey defaultName: String) {
        dictionaryStorage[defaultName] = nil
    }
    
    override func setValue(_ value: Any?, forKey key: String) {
        dictionaryStorage[key] = value
    }

    override func double(forKey defaultName: String) -> Double {
        dictionaryStorage[defaultName] as? Double ?? 0
    }
    
    override func object(forKey defaultName: String) -> Any? {
        return dictionaryStorage[defaultName]
    }

    override func synchronize() -> Bool {
        synchronizeInvoked = true
        return true
    }
    
    override func dictionary(forKey defaultName: String) -> [String : Any]? {
        return dictionaryStorage[defaultName] as? [String : Any]
    }
}

