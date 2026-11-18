import AppAuth
import XCTest
@testable import BNAppAuth

final class keychain_wrapperTests: XCTestCase {
    
    var sut: KeychainWrapper!
    var securityMock: SecurityMock!
    
    override func setUpWithError() throws {
        super.setUp()
        
        securityMock = SecurityMock()
        sut = KeychainWrapper(
            addFunction: securityMock.SecItemAdd,
            copyFunction: securityMock.SecItemCopyMatching,
            deleteFunction: securityMock.SecItemDelete
        )
    }
        
    override func tearDownWithError() throws {
        sut = nil
        super.tearDown()
    }
    
    
    func testDataForKey_withNoStoredData_shouldReturnNil() {
        XCTAssertNil(sut.data(forKey: "test-key"))
    }
    
    func testDataForKey_withStoredData_shouldReturnData() {
        sut.set("Test".data(using: .utf8)!, forKey: "test-key")
        XCTAssertNotNil(sut.data(forKey: "test-key"))
    }
    
    func testSetDataForKey_shouldStoreData() {
        sut.set("Test".data(using: .utf8)!, forKey: "test-key")
        XCTAssertNotNil(securityMock._secureStore["test-key"])
    }
    
    func testSetDataForKey_shouldBeReadableAfterFirstUnlock() {
        sut.set("Test".data(using: .utf8)!, forKey: "test-key")
        let accessible = securityMock._secureStore["test-key"]?[kSecAttrAccessible as String] as? String
        XCTAssertEqual(accessible, kSecAttrAccessibleAfterFirstUnlock as String)
    }

    func testSetDataForKey_shouldDeleteOldItemWhateverItsAccessibility() {
        var deleteQueries: [[String: Any]] = []
        sut = KeychainWrapper(
            addFunction: securityMock.SecItemAdd,
            copyFunction: securityMock.SecItemCopyMatching,
            deleteFunction: { query in
                deleteQueries.append(query as? [String: Any] ?? [:])
                return errSecSuccess
            }
        )
        sut.set("Test".data(using: .utf8)!, forKey: "test-key")
        XCTAssertEqual(deleteQueries.count, 1)
        XCTAssertNil(deleteQueries.first?[kSecAttrAccessible as String])
    }

    func testDeleteForKey_shouldRemoveData() {
        sut.set("Test".data(using: .utf8)!, forKey: "test-key")
        XCTAssertNotNil(securityMock._secureStore["test-key"])
        sut.delete(forKey: "test-key")
        XCTAssertNil(securityMock._secureStore["test-key"])
    }
}


/*
 func data(forKey key: String) -> Data?
 func set(_ data: Data, forKey key: String)
 func delete(forKey key: String)
 */
