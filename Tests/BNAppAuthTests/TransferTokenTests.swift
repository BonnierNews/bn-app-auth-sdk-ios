import AppAuth
import XCTest
@testable import BNAppAuth

final class TransferTokenTests: XCTestCase {

    var sut: BNAppAuth!
    var authStorageMock: AuthStorageMock!
    var authServiceMock: AuthorizationServiceMock.Type!
    var authState: AuthStateMock!

    let siteUrl = URL(string: "https://www.site.se/sport/?a=1")!

    override func setUpWithError() throws {
        super.setUp()

        authStorageMock = AuthStorageMock()
        authServiceMock = AuthorizationServiceMock.self
        authServiceMock.reset()
        let userDefaultsMock = UserDefaultsMock()
        userDefaultsMock.set(true, forKey: UserDefaultsKeys.BnMigrationCompleted.rawValue)

        sut = BNAppAuth(
            authStorage: authStorageMock,
            authService: authServiceMock,
            authFlowBuilder: AuthorizationFlowBuilderMock(),
            userDefaults: userDefaultsMock
        )
        sut.configure(client: MockHelper.clientConfiguration())

        authState = MockHelper.authStateMock()
        authState.performActionAccessTokenReturnValue = "accessToken"
        authStorageMock._storedState = authState

        authServiceMock.performReturnValue = OIDTokenResponse(
            request: OIDTokenRequest(
                configuration: authServiceMock.configurationReturnValue,
                grantType: TransferTokenExchange.tokenExchangeGrantType,
                authorizationCode: nil,
                redirectURL: nil,
                clientID: "client-id",
                clientSecret: nil,
                scope: nil,
                refreshToken: nil,
                codeVerifier: nil,
                additionalParameters: nil
            ),
            parameters: [
                "access_token": "transferToken" as NSString,
                "token_type": "N_A" as NSString,
                "issued_token_type": TransferTokenExchange.sessionTransferTokenType as NSString
            ]
        )
    }

    override func tearDownWithError() throws {
        sut = nil
        authStorageMock = nil
        authState = nil
        super.tearDown()
    }

    func testGetTransferToken_exchangesAFreshAccessTokenAtTheSessionsTokenEndpoint() async throws {
        let token = try await sut.getTransferToken(resource: siteUrl)

        XCTAssertEqual(token, "transferToken")
        let request = try XCTUnwrap(authServiceMock.performLastRequest)
        XCTAssertEqual(request.configuration.tokenEndpoint, authServiceMock.configurationReturnValue.tokenEndpoint)
        XCTAssertEqual(request.clientID, "client-id")
        XCTAssertEqual(request.additionalParameters?["subject_token"], "accessToken")
        XCTAssertEqual(request.additionalParameters?["resource"], siteUrl.absoluteString)
    }

    func testGetTransferToken_neverReplacesTheUsersOwnTokens() async throws {
        _ = try await sut.getTransferToken(resource: siteUrl)

        XCTAssertEqual(authStorageMock.storeInvokeCount, 0)
        XCTAssertTrue(authStorageMock._storedState === authState)
    }

    func testGetTransferToken_whenLoggedOut_shouldReturnNilWithoutRequest() async throws {
        authStorageMock._storedState = nil

        let token = try await sut.getTransferToken(resource: siteUrl)

        XCTAssertNil(token)
        XCTAssertEqual(authServiceMock.performInvokeCount, 0)
    }
}
