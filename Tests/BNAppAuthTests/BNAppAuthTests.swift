import AppAuth
import XCTest
@testable import BNAppAuth

final class bn_app_authTests: XCTestCase {
    
    var sut: BNAppAuth!
    var authStorageMock: AuthStorageMock!
    var authServiceMock: AuthorizationServiceMock.Type!
    var authFlowBuilderMock: AuthorizationFlowBuilderMock!
    var userDefaultsMock: UserDefaultsMock!
    var delegateMock: UIViewController!
    
    override func setUpWithError() throws {
        super.setUp()
        
        authStorageMock = AuthStorageMock()
        authServiceMock = AuthorizationServiceMock.self
        authServiceMock.reset()
        authFlowBuilderMock = AuthorizationFlowBuilderMock()
        userDefaultsMock = UserDefaultsMock()
        userDefaultsMock.set(true, forKey: UserDefaultsKeys.BnMigrationCompleted.rawValue)
    
        
        delegateMock = UIViewController()
        
        sut = BNAppAuth(
            authStorage: authStorageMock,
            authService: authServiceMock,
            authFlowBuilder: authFlowBuilderMock,
            userDefaults: userDefaultsMock,
        )
    }

    override func tearDownWithError() throws {
        sut = nil
        authStorageMock = nil
        authFlowBuilderMock = nil
        delegateMock = nil
        super.tearDown()
    }
    
    func testGetIdToken_withNoClientConfiguration_shouldReturnNil() throws {
        authStorageMock._storedState = MockHelper.authStateMock()
        let expectation = XCTestExpectation(description: "Call getIdToken() with completion")
        
        sut.getIdToken() { result in
            switch result {
            case .success(let value):
                XCTAssertNil(value)
            case .failure:
                XCTFail("Should not produce an error")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation])
    }
    
    func testGetIdToken_withNoAuthState_shouldReturnNil() throws {
        let expectation = XCTestExpectation(description: "Call getIdToken() with completion")
        
        sut.getIdToken() { result in
            switch result {
            case .success(let value):
                XCTAssertNil(value)
            case .failure:
                XCTFail("Should not produce an error")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation])
    }

    func testGetIdToken_withAuthState_shouldReturnToken_withIsUpdatedFalse() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        authStorageMock._storedState = MockHelper.authStateMock()
        let expectation = XCTestExpectation(description: "Call getIdToken() with completion")

        sut.getIdToken() { result in
            switch result {
            case .success(let tokenResult):
                XCTAssertNotNil(tokenResult)
                XCTAssertFalse(tokenResult!.isUpdated)
            case .failure:
                XCTFail("Should not produce an error")
            }
            expectation.fulfill()
        }

        wait(for: [expectation])
    }
    
    func testGetIdToken_withAuthState_shouldReturnToken_withIsUpdatedTrue() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        let authState = MockHelper.authStateMock()
        authStorageMock._storedState = authState
        let expectation = XCTestExpectation(description: "Call getIdToken() with completion")

        authState.performActionIdTokenReturnValue = "newIdToken"
        
        sut.getIdToken() { result in
            switch result {
            case .success(let tokenResult):
                XCTAssertNotNil(tokenResult)
                XCTAssertTrue(tokenResult!.isUpdated)
            case .failure:
                XCTFail("Should not produce an error")
            }
            expectation.fulfill()
        }

        wait(for: [expectation])
    }
    
    
    func testGetIdToken_withExchange_shouldReturnToken() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        let authState = MockHelper.authStateMock()
        authStorageMock._storedState = authState
        let expectation = XCTestExpectation(description: "Call getIdToken() with completion")
        userDefaultsMock.set(false, forKey: UserDefaultsKeys.BnMigrationCompleted.rawValue)
        authState.performActionIdTokenReturnValue = "newIdToken"
        authServiceMock.performReturnValue = TokenResponseMock(
            request: OIDTokenRequest(
                configuration: AuthorizationServiceMock.configurationReturnValue,
                grantType: "exchange-token",
                authorizationCode: nil,
                redirectURL: nil,
                clientID: "clientId",
                clientSecret: nil,
                scope: nil,
                refreshToken: nil,
                codeVerifier: nil,
                additionalParameters: nil
            ),
            parameters: [:]
        )
        
        sut.getIdToken() { result in
            switch result {
            case .success(let tokenResult):
                XCTAssertNotNil(tokenResult)
            case .failure:
                XCTFail("Should not produce an error")
            }
            expectation.fulfill()
        }

        wait(for: [expectation])
    }
    
    func testGetIdToken_withAuthState_shouldReturnToken_withLoginToken() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        let authState = MockHelper.authStateMock(loginToken: "testToken")
        authStorageMock._storedState = authState
        let expectation = XCTestExpectation(description: "Call getIdToken() with completion")
        authState.performActionIdTokenReturnValue = "newIdToken"
        
        sut.getIdToken(getLoginToken: true) { result in
            switch result {
            case .success(let tokenResult):
                XCTAssertNotNil(tokenResult)
                XCTAssertNotNil(tokenResult!.loginToken)
                XCTAssertTrue(tokenResult!.isUpdated)
            case .failure:
                XCTFail("Should not produce an error")
            }
            expectation.fulfill()
        }

        wait(for: [expectation])
    }
    
    func testMultipleGetIdToken_withAuthState_shouldReturnToken_withIsUpdatedTrue_forFirstRequest() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        let authState = MockHelper.authStateMock()
        authStorageMock._storedState = authState
        let expectation1 = XCTestExpectation(description: "Call getIdToken() with completion")
        let expectation2 = XCTestExpectation(description: "Call getIdToken() with completion")
        let expectation3 = XCTestExpectation(description: "Call getIdToken() with completion")

        authState.performActionIdTokenReturnValue = "newIdToken"
        
        sut.getIdToken() { result in
            switch result {
            case .success(let tokenResult):
                XCTAssertNotNil(tokenResult)
                XCTAssertTrue(tokenResult!.isUpdated)
            case .failure:
                XCTFail("Should not produce an error")
            }
            expectation1.fulfill()
        }
        
        sut.getIdToken() { result in
            switch result {
            case .success(let tokenResult):
                XCTAssertNotNil(tokenResult)
                XCTAssertFalse(tokenResult!.isUpdated)
            case .failure:
                XCTFail("Should not produce an error")
            }
            expectation2.fulfill()
        }
        
        sut.getIdToken(forceRefresh: true) { result in
            switch result {
            case .success(let tokenResult):
                XCTAssertNotNil(tokenResult)
                XCTAssertFalse(tokenResult!.isUpdated)
            case .failure:
                XCTFail("Should not produce an error")
            }
            expectation3.fulfill()
        }

        wait(for: [expectation1,expectation2,expectation3])
    }

    func testGetIdToken_whenPerformActionReturnsError_shouldReturnError() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        let authState = MockHelper.authStateMock()
        authState.performActionErrorReturnValue = NSError(domain: "idToken", code: 0)
        authState.performActionIdTokenReturnValue = nil
        authStorageMock._storedState = authState
        let expectation = XCTestExpectation(description: "Call getIdToken() with completion")

        sut.getIdToken() { result in
            switch result {
            case .success:
                XCTFail("Should not produce success")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            expectation.fulfill()
        }

        wait(for: [expectation])
    }
    
    func testGetIdToken_whenPerformActionReturnsNetworkError_shouldReturnSuccess() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        let authState = MockHelper.authStateMock()
        authState.performActionErrorReturnValue = NSError(domain: "idToken", code: -5)
        authState.performActionIdTokenReturnValue = nil
        authStorageMock._storedState = authState
        let expectation = XCTestExpectation(description: "Call getIdToken() with completion")

        sut.getIdToken() { result in
            switch result {
            case .success(let idToken):
                XCTAssertNotNil(idToken)
            case .failure:
                XCTFail("Should not produce error")
            }
            expectation.fulfill()
        }

        wait(for: [expectation])
    }

    func testLogin_configureNotCalledAndNoDelegate_shouldReturnError() throws {
        sut.login() { result in
            switch result {
            case .success:
                XCTFail("Should not produce success")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
        }
    }
    
    func testLogin_configureNotCalled_shouldReturnError() throws {
        sut.delegate = delegateMock
        sut.login() { result in
            switch result {
            case .success:
                XCTFail("Should not produce success")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
        }
    }
    
    func testLogin_noDelegate_shouldReturnError() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.login() { result in
            switch result {
            case .success:
                XCTFail("Should not produce success")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
        }
    }
    
    func testLogin_configuredAndWithDelegate_shouldCallDiscoveryAndDefaultAuthorizationFlowBuilder() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.delegate = delegateMock
        
        let discoveryExpectation = XCTestExpectation(description: "Call to discoverConfiguration was made")
        let defaultAuthorizationFlowExpectation = XCTestExpectation(description: "Call to AuthorizationFlowBuilder for defaultAuthorizationFlow was made")
        
        authServiceMock.discoverConfigurationWasCalled = {
            discoveryExpectation.fulfill()
        }
        authFlowBuilderMock.defaultAuthorizationFlowWasCalledTimes = { _ in
            defaultAuthorizationFlowExpectation.fulfill()
        }
        
        sut.login() { result in
            XCTFail("Should not get here")
        }
        
        wait(for: [discoveryExpectation, defaultAuthorizationFlowExpectation], timeout: 2)
    }
    
    func testLogin_withToken_configuredAndWithDelegate_shouldHaveIncludedTokenInRequest() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.delegate = delegateMock
        
        let defaultAuthorizationFlowExpectation = XCTestExpectation(description: "Call to AuthorizationFlowBuilder for defaultAuthorizationFlow was made")

        authFlowBuilderMock.defaultAuthorizationFlowWasCalledTimes = { [weak self] _ in
            if let request = self?.authFlowBuilderMock.defaultAuthorizationFlowLastRequest {
                XCTAssert(request.additionalParameters?["token"] == "a-token")
            } else {
                XCTFail("Should not get here")
            }
            
            defaultAuthorizationFlowExpectation.fulfill()
        }
        
        sut.login(token: "a-token") { result in
            XCTFail("Should not get here")
        }
        
        wait(for: [defaultAuthorizationFlowExpectation], timeout: 2)
    }
    
    func testLogin_authFlowCallbackTriggered_shouldReturnResult() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.delegate = delegateMock
        
        let loginExpectation = XCTestExpectation(description: "Call to login should return callback")

        authFlowBuilderMock.defaultAuthorizationFlowWasCalledTimes = { [weak self] _ in
            self?.authFlowBuilderMock.defaultAuthorizationFlowLastCompletion?(MockHelper.authStateMock(), nil)
        }
        
        sut.login() { result in
            switch result {
            case .success(let value):
                XCTAssertNotNil(value)
            case .failure:
                XCTFail("Should not produce an error")
            }
            loginExpectation.fulfill()
        }

        wait(for: [loginExpectation], timeout: 2)
    }
    
    func testLogin_authFlowCallbackTriggered_shouldSetIsAuthorizedToTrue() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.delegate = delegateMock
        
        let loginExpectation = XCTestExpectation(description: "Call to login should return callback")

        
        authFlowBuilderMock.defaultAuthorizationFlowWasCalledTimes = { [weak self] _ in
            let authState = MockHelper.authStateMock()

            self?.authFlowBuilderMock.defaultAuthorizationFlowLastCompletion?(authState, nil)
        }
        
        sut.login() { [weak self] result in
            XCTAssertTrue(self?.sut.isAuthorized == true)
            loginExpectation.fulfill()
        }

        wait(for: [loginExpectation], timeout: 2)
    }
    
    func testLogout_configureNotCalledAndNoDelegate_shouldReturnError() throws {
        sut.logout() { result in
            switch result {
            case .success:
                XCTFail("Should not produce success")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
        }
    }
    
    func testLogout_configureNotCalled_shouldReturnError() throws {
        sut.delegate = delegateMock
        sut.login() { result in
            switch result {
            case .success:
                XCTFail("Should not produce success")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
        }
    }
    
    func testLogout_noDelegate_shouldReturnError() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.login() { result in
            switch result {
            case .success:
                XCTFail("Should not produce success")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
        }
    }
    
    func testLogout_configuredAndWithDelegate_shouldCallDiscoveryAndDefaultAuthorizationFlowBuilder() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.delegate = delegateMock
        
        let discoveryExpectation = XCTestExpectation(description: "Call to discoverConfiguration was made")
        let defaultAuthorizationFlowExpectation = XCTestExpectation(description: "Call to AuthorizationFlowBuilder for defaultEndSessionFlow was made")
        
        authServiceMock.discoverConfigurationWasCalled = {
            discoveryExpectation.fulfill()
        }
        authFlowBuilderMock.defaultEndSessionFlowWasCalledTimes = { _ in
            defaultAuthorizationFlowExpectation.fulfill()
        }
        
        sut.logout() { result in
            XCTFail("Should not get here")
        }
        
        wait(for: [discoveryExpectation, defaultAuthorizationFlowExpectation], timeout: 2)
    }
    
    func testLogout_authFlowCallbackTriggered_shouldReturnResult() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.delegate = delegateMock
        
        let loginExpectation = XCTestExpectation(description: "Call to logout should return callback")
        
        authFlowBuilderMock.defaultEndSessionFlowWasCalledTimes = { [weak self] _ in
            if let request = self?.authFlowBuilderMock.defaultEndSessionFlowLastRequest {
                self?.authFlowBuilderMock.defaultEndSessionFlowLastCompletion?(OIDEndSessionResponse(request: request, parameters: [:]), nil)
            }
        }
        
        sut.logout() { result in
            switch result {
            case .success(let value):
                XCTAssertNotNil(value)
            case .failure:
                XCTFail("Should not produce an error")
            }
            loginExpectation.fulfill()
        }

        wait(for: [loginExpectation], timeout: 2)
    }
    
    func testLogout_authFlowCallbackTriggeredWithError_shouldReturnSuccess() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.delegate = delegateMock
        
        let loginExpectation = XCTestExpectation(description: "Call to logout should return callback")
        
        authFlowBuilderMock.defaultEndSessionFlowWasCalledTimes = { [weak self] _ in
            if let _ = self?.authFlowBuilderMock.defaultEndSessionFlowLastRequest {
                self?.authFlowBuilderMock.defaultEndSessionFlowLastCompletion?(nil, NSError(domain: "test", code: OIDErrorCode.idTokenParsingError.rawValue) )
            }
        }
        
        sut.logout() { result in
            switch result {
            case .success(let value):
                XCTAssertNotNil(value)
            case .failure:
                XCTFail("Should not produce an error")
            }
            loginExpectation.fulfill()
        }

        wait(for: [loginExpectation], timeout: 2)
    }
    
    func testLogout_authFlowCallbackTriggeredWithUserCancelledError_shouldReturnFailed() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.delegate = delegateMock
        
        let loginExpectation = XCTestExpectation(description: "Call to logout should return callback")
        
        authFlowBuilderMock.defaultEndSessionFlowWasCalledTimes = { [weak self] _ in
            if let _ = self?.authFlowBuilderMock.defaultEndSessionFlowLastRequest {
                self?.authFlowBuilderMock.defaultEndSessionFlowLastCompletion?(nil, NSError(domain: "test", code: OIDErrorCode.userCanceledAuthorizationFlow.rawValue) )
            }
        }
        
        sut.logout() { result in
            switch result {
            case .success:
                XCTFail("Should not produce success")
            case .failure(let error):
                XCTAssert((error as NSError).code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue)
            }
            loginExpectation.fulfill()
        }

        wait(for: [loginExpectation], timeout: 2)
    }
    
    func testCreateAccount_callingLoginWithAction_shouldHaveIncludedActionInRequest() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.delegate = delegateMock
        
        let defaultAuthorizationFlowExpectation = XCTestExpectation(description: "Call to AuthorizationFlowBuilder for defaultAuthorizationFlow was made")

        authFlowBuilderMock.defaultAuthorizationFlowWasCalledTimes = { [weak self] _ in
            if let request = self?.authFlowBuilderMock.defaultAuthorizationFlowLastRequest {
                XCTAssert(request.additionalParameters?["action"] == "create-user")
            } else {
                XCTFail("Should not get here")
            }
            
            defaultAuthorizationFlowExpectation.fulfill()
        }
        
        sut.createAccount() { result in
            XCTFail("Should not get here")
        }
        
        wait(for: [defaultAuthorizationFlowExpectation], timeout: 2)
    }
    
    func testLogin_withLocaleSet_shouldHaveIncludedParameterInRequest() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.delegate = delegateMock
        
        let defaultAuthorizationFlowExpectation = XCTestExpectation(description: "Call to AuthorizationFlowBuilder for defaultAuthorizationFlow was made")

        authFlowBuilderMock.defaultAuthorizationFlowWasCalledTimes = { [weak self] _ in
            if let request = self?.authFlowBuilderMock.defaultAuthorizationFlowLastRequest {
                XCTAssert(request.additionalParameters?["ui_locales"] == "sv-SE")
            } else {
                XCTFail("Should not get here")
            }
            
            defaultAuthorizationFlowExpectation.fulfill()
        }
        
        sut.login(locale: "sv-SE") { result in
            XCTFail("Should not get here")
        }
        
        wait(for: [defaultAuthorizationFlowExpectation], timeout: 2)
    }
    
    func testCreateAccount_withLocaleSet_shouldHaveIncludedParameterInRequest() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        sut.delegate = delegateMock
        
        let defaultAuthorizationFlowExpectation = XCTestExpectation(description: "Call to AuthorizationFlowBuilder for defaultAuthorizationFlow was made")

        authFlowBuilderMock.defaultAuthorizationFlowWasCalledTimes = { [weak self] _ in
            if let request = self?.authFlowBuilderMock.defaultAuthorizationFlowLastRequest {
                XCTAssert(request.additionalParameters?["ui_locales"] == "sv-SE")
                XCTAssert(request.additionalParameters?["action"] == "create-user")
            } else {
                XCTFail("Should not get here")
            }
            
            defaultAuthorizationFlowExpectation.fulfill()
        }
        
        sut.createAccount(locale: "sv-SE") { result in
            XCTFail("Should not get here")
        }
        
        wait(for: [defaultAuthorizationFlowExpectation], timeout: 2)
    }

    func testClearState_whenStateIsSet_shouldClearState() throws {
        authStorageMock._storedState = MockHelper.authStateMock()

        XCTAssertTrue(sut.isAuthorized)
        sut.clearState()
        XCTAssertFalse(sut.isAuthorized)
    }
    
    func testDidChange_whenStateCallsDelegate_keychainWrapperSetShouldBeCalled() throws {
        let state = MockHelper.authStateMock()
        sut.didChange(state)
        XCTAssert(authStorageMock.storeInvokeCount == 1)
    }
    
    func test_customScopes() throws {
        sut.configure(client: MockHelper.clientConfiguration(customScopes: ["profile", "offline_access", "customScope1", "customScope2"]))
        sut.delegate = delegateMock
        
        let defaultAuthorizationFlowExpectation = XCTestExpectation(description: "Call to AuthorizationFlowBuilder for defaultAuthorizationFlow was made")

        authFlowBuilderMock.defaultAuthorizationFlowWasCalledTimes = { [weak self] _ in
            if let request = self?.authFlowBuilderMock.defaultAuthorizationFlowLastRequest {
                XCTAssert(request.scope == "openid profile offline_access customScope1 customScope2")
            } else {
                XCTFail("Should not get here")
            }
            
            defaultAuthorizationFlowExpectation.fulfill()
        }
        
        sut.login(locale: "sv-SE") { result in
            XCTFail("Should not get here")
        }
        
        wait(for: [defaultAuthorizationFlowExpectation], timeout: 2)
    }
    
    func testGetIdToken_whenMigrationRequired_shouldPerformExchangeAndReturnToken() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        userDefaultsMock.set(false, forKey: UserDefaultsKeys.BnMigrationCompleted.rawValue)

        let mockState = MockHelper.authStateMock()
        mockState.performActionIdTokenReturnValue = "final-token"
        authStorageMock._storedState = mockState

        authServiceMock.performReturnValue = TokenResponseMock(
            request: OIDTokenRequest(
                configuration: AuthorizationServiceMock.configurationReturnValue,
                grantType: "urn:ietf:params:oauth:grant-type:token-exchange",
                authorizationCode: nil,
                redirectURL: nil,
                clientID: "clientId",
                clientSecret: nil,
                scopes: ["openid"],
                refreshToken: nil,
                codeVerifier: nil,
                additionalParameters: nil
            ),
            parameters: ["id_token": "migrated-token" as NSString]
        )

        let expectation = XCTestExpectation(description: "Migration should complete")

        sut.getIdToken { result in
            if case .success(let tokenResult) = result {
                XCTAssertNotNil(tokenResult)
                XCTAssertEqual(tokenResult?.idToken, "final-token")
            } else {
                XCTFail("Migration failed")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }
    
    func testGetIdToken_whenMigrationFails_shouldClearStateAndReturnError() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        userDefaultsMock.set(false, forKey: UserDefaultsKeys.BnMigrationCompleted.rawValue)
        
        authStorageMock._storedState = MockHelper.authStateMock()
        
        AuthorizationServiceMock.performErrorReturnValue = NSError(domain: "test", code: 401)
        
        let expectation = XCTestExpectation(description: "Migration should fail and clear state")

        sut.getIdToken { result in
            if case .failure = result {
                XCTAssertFalse(self.sut.isAuthorized)
                XCTAssertFalse(self.userDefaultsMock.bool(forKey: UserDefaultsKeys.BnMigrationCompleted.rawValue))
            } else {
                XCTFail("Should have failed due to mock error")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }
    
    func testGetIdToken_multipleConcurrentCalls_shouldOnlyPerformOneMigration() throws {
        sut.configure(client: MockHelper.clientConfiguration())
        userDefaultsMock.set(false, forKey: UserDefaultsKeys.BnMigrationCompleted.rawValue)
        
        let mockState = MockHelper.authStateMock()
        mockState.performActionIdTokenReturnValue = "final-token"
        authStorageMock._storedState = mockState

        AuthorizationServiceMock.performReturnValue = TokenResponseMock(
            request: OIDTokenRequest(
                configuration: AuthorizationServiceMock.configurationReturnValue,
                grantType: "exchange",
                authorizationCode: nil,
                redirectURL: nil,
                clientID: "clientId",
                clientSecret: nil,
                scopes: nil,
                refreshToken: nil,
                codeVerifier: nil,
                additionalParameters: nil
            ),
            parameters: ["id_token": "migrated-token" as NSString]
        )

        let exp1 = XCTestExpectation(description: "Call 1")
        let exp2 = XCTestExpectation(description: "Call 2")
        let exp3 = XCTestExpectation(description: "Call 3")

        sut.getIdToken { _ in exp1.fulfill() }
        sut.getIdToken { _ in exp2.fulfill() }
        sut.getIdToken { _ in exp3.fulfill() }

        wait(for: [exp1, exp2, exp3], timeout: 5)
        
        XCTAssertEqual(AuthorizationServiceMock.performInvokeCount, 1, "The 'Mutex' logic failed: Multiple migration requests were fired.")
    }
}
