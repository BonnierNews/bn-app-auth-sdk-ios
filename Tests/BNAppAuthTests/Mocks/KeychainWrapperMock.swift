import Foundation
@testable import BNAppAuth

class KeychainWrapperMock: KeychainWrapping {
    var _data: [String:Data] = [:]
    
    var dataForKeyInvokeCount = 0
    var dataForKeyWasCalled: ((Int) -> Void)?
    var dataForKeyLastKey: String?
    func data(forKey key: String) -> Data? {
        dataForKeyInvokeCount += 1
        dataForKeyWasCalled?(dataForKeyInvokeCount)
        return _data[key]
    }
    
    var setDataForKeyInvokeCount = 0
    var setDataForKeyWasCalled: ((Int) -> Void)?
    func set(_ data: Data, forKey key: String) {
        _data[key] = data
        setDataForKeyInvokeCount += 1
        setDataForKeyWasCalled?(setDataForKeyInvokeCount)
    }
    
    var deleteForKeyInvokeCount = 0
    var deleteForKeyWasCalled: ((Int) -> Void)?
    func delete(forKey key: String) {
        _data[key] = nil
        deleteForKeyInvokeCount += 1
        deleteForKeyWasCalled?(deleteForKeyInvokeCount)
    }
}
