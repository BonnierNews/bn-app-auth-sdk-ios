import AppAuth
@testable import BNAppAuth

class AuthStorageMock: NSObject, AuthStoraging {

    var _storedState: TestableAuthState?
    
    func getStoredState<T: OIDAuthState>() -> T? {
        _storedState as? T
    }
    
    var storeInvokeCount = 0
    var storeWasCalledTimes: ((Int) -> Void)?
    func store<T: OIDAuthState>(_ state: T) {
        _storedState = state
        storeInvokeCount += 1
        storeWasCalledTimes?(storeInvokeCount)
    }
    
    func delete() {
        _storedState = nil
    }
    
    func didChange(_ state: OIDAuthState) {
        _storedState = state
    }
}
