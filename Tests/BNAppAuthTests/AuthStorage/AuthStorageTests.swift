import AppAuth
import XCTest
@testable import BNAppAuth

final class auth_storageTests: XCTestCase {
    
    var sut: AuthStorage!
    var keychainWrapperMock: KeychainWrapperMock!

    override func setUpWithError() throws {
        super.setUp()
        
        keychainWrapperMock = KeychainWrapperMock()
        sut = AuthStorage(keychain: keychainWrapperMock)
    }
        
    override func tearDownWithError() throws {
        sut = nil
        super.tearDown()
    }
    
    func testStoredState_withNothingStored_shouldReturnNil() throws {
        XCTAssertNil(sut.getStoredState())
    }
    
    func testStoredState_withStoredState_shouldReturnState() throws {
        let state = MockHelper.authStateMock()
        sut.store(state)
        XCTAssertNotNil(sut.getStoredState)
    }
    
    func testStore_whenStoringState_keychainWrapperSetShouldBeCalled() throws {
        let state = MockHelper.authStateMock()
        sut.store(state)
        XCTAssertNotNil(keychainWrapperMock.setDataForKeyInvokeCount == 1)
    }
    
    func testDelete_whenDeletingState_keychainWrapperDeleteShouldBeCalled() throws {
        sut.delete()
        XCTAssert(keychainWrapperMock.deleteForKeyInvokeCount == 1)
    }
}
