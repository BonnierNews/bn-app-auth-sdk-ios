import AppAuth
import XCTest
@testable import BNAppAuth

final class TransferTokenExchangeTests: XCTestCase {

    let siteUrl = URL(string: "https://www.site.se/sport/?a=1")!
    let serviceConfiguration = AuthorizationServiceMock.configurationReturnValue

    var requests: [OIDTokenRequest] = []
    var accessToken: String? = "accessToken"
    var issuedTokenType = TransferTokenExchange.sessionTransferTokenType
    var response: (OIDTokenRequest) async throws -> OIDTokenResponse? = { _ in nil }
    var time = Date(timeIntervalSince1970: 0)

    override func setUp() {
        super.setUp()
        requests = []
        accessToken = "accessToken"
        issuedTokenType = TransferTokenExchange.sessionTransferTokenType
        response = { [unowned self] request in
            OIDTokenResponse(
                request: request,
                parameters: [
                    "access_token": "transferToken" as NSString,
                    "token_type": "N_A" as NSString,
                    "issued_token_type": self.issuedTokenType as NSString
                ]
            )
        }
        time = Date(timeIntervalSince1970: 0)
    }

    private func makeExchange(
        client: BNAppAuth.ClientConfiguration? = MockHelper.clientConfiguration(),
        timeout: TimeInterval = TransferTokenExchange.timeout
    ) -> TransferTokenExchange {
        TransferTokenExchange(
            client: { client },
            freshAccessToken: { [unowned self] in self.accessToken },
            serviceConfiguration: { [unowned self] in self.serviceConfiguration },
            performTokenRequest: { [unowned self] request in
                self.requests.append(request)
                return try await self.response(request)
            },
            timeout: timeout,
            now: { [unowned self] in self.time }
        )
    }

    private func tokenError(_ error: String) -> NSError {
        NSError(
            domain: OIDOAuthTokenErrorDomain,
            code: OIDErrorCodeOAuth.other.rawValue,
            userInfo: [OIDOAuthErrorResponseErrorKey: [OIDOAuthErrorFieldError: error]]
        )
    }

    func testTransferToken_asksForASessionTransferTokenForTheUrl() async throws {
        let token = try await makeExchange().transferToken(resource: siteUrl)

        XCTAssertEqual(token, "transferToken")
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(request.configuration.tokenEndpoint, serviceConfiguration.tokenEndpoint)
        XCTAssertEqual(request.grantType, TransferTokenExchange.tokenExchangeGrantType)
        XCTAssertEqual(request.clientID, "client-id")
        XCTAssertEqual(request.scope, "openid")
        XCTAssertEqual(request.additionalParameters, [
            "subject_token": "accessToken",
            "subject_token_type": TransferTokenExchange.accessTokenType,
            "requested_token_type": TransferTokenExchange.sessionTransferTokenType,
            "resource": siteUrl.absoluteString
        ])
    }

    func testTransferToken_whenIdServiceIssuesAnotherKindOfToken_shouldReturnNil() async throws {
        issuedTokenType = "urn:bonniernews:oauth:token-type:login_token"

        let token = try await makeExchange().transferToken(resource: siteUrl)

        XCTAssertNil(token)
    }

    func testTransferToken_beforeConfigure_shouldReturnNilWithoutRequest() async throws {
        let token = try await makeExchange(client: nil).transferToken(resource: siteUrl)

        XCTAssertNil(token)
        XCTAssertEqual(requests.count, 0)
    }

    func testTransferToken_whenLoggedOut_shouldReturnNilWithoutRequest() async throws {
        accessToken = nil

        let token = try await makeExchange().transferToken(resource: siteUrl)

        XCTAssertNil(token)
        XCTAssertEqual(requests.count, 0)
    }

    func testTransferToken_neverIssuesATokenForAnHttpUrl() async throws {
        let token = try await makeExchange().transferToken(resource: URL(string: "http://www.site.se/sport/")!)

        XCTAssertNil(token)
        XCTAssertEqual(requests.count, 0)
    }

    func testTransferToken_whenIdServiceHasNoClient_shouldReturnNilWithoutThrowing() async throws {
        let error = tokenError(TransferTokenExchange.invalidTarget)
        response = { _ in throw error }

        let token = try await makeExchange().transferToken(resource: siteUrl)

        XCTAssertNil(token)
    }

    func testTransferToken_remembersOriginsWithoutIdServiceLogin() async throws {
        let error = tokenError(TransferTokenExchange.invalidTarget)
        response = { _ in throw error }
        let exchange = makeExchange()

        _ = try await exchange.transferToken(resource: siteUrl)
        _ = try await exchange.transferToken(resource: URL(string: "https://WWW.SITE.SE:443/other/")!)
        _ = try await exchange.transferToken(resource: URL(string: "https://www.site.se:8443/other/")!)

        XCTAssertEqual(requests.count, 2)
    }

    func testTransferToken_asksAgainOnceAnOriginWithoutLoginHasExpired() async throws {
        let error = tokenError(TransferTokenExchange.invalidTarget)
        response = { _ in throw error }
        let exchange = makeExchange()

        _ = try await exchange.transferToken(resource: siteUrl)
        time = time.addingTimeInterval(TransferTokenExchange.originWithoutLoginTTL + 1)
        _ = try await exchange.transferToken(resource: siteUrl)

        XCTAssertEqual(requests.count, 2)
    }

    func testTransferToken_whenExchangeFails_shouldThrowAndAskAgainNextTime() async throws {
        let error = tokenError("invalid_grant")
        response = { _ in throw error }
        let exchange = makeExchange()

        do {
            _ = try await exchange.transferToken(resource: siteUrl)
            XCTFail("Should throw")
        } catch {}
        _ = try? await exchange.transferToken(resource: siteUrl)

        XCTAssertEqual(requests.count, 2)
    }

    func testTransferToken_whenIdServiceIsTooSlow_shouldReturnNil() async throws {
        let respond = response
        response = { request in
            try await Task.sleep(nanoseconds: 10_000_000_000)
            return try await respond(request)
        }

        let token = try await makeExchange(timeout: 0.1).transferToken(resource: siteUrl)

        XCTAssertNil(token)
    }
}
