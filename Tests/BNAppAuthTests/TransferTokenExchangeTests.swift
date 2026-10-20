import AppAuth
import XCTest
@testable import BNAppAuth

final class TransferTokenExchangeTests: XCTestCase {

    let siteUrl = URL(string: "https://www.site.se/sport/?a=1")!
    let serviceConfiguration = AuthorizationServiceMock.configurationReturnValue

    var requests: [OIDTokenRequest] = []
    var accessToken: String? = "accessToken"
    var response: () async throws -> String? = { "transferToken" }
    var time = Date(timeIntervalSince1970: 0)

    override func setUp() {
        super.setUp()
        requests = []
        accessToken = "accessToken"
        response = { "transferToken" }
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
                return try await self.response()
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

    func testTransferToken_forResource_asksForATokenForTheUrl() async throws {
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
            "resource": siteUrl.absoluteString
        ])
    }

    func testTransferToken_forAudience_asksForATokenForTheClient() async throws {
        let token = try await makeExchange().transferToken(audience: "site-web")

        XCTAssertEqual(token, "transferToken")
        XCTAssertEqual(requests.first?.additionalParameters, [
            "subject_token": "accessToken",
            "subject_token_type": TransferTokenExchange.accessTokenType,
            "audience": "site-web"
        ])
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
        response = { throw error }

        let token = try await makeExchange().transferToken(resource: siteUrl)

        XCTAssertNil(token)
    }

    func testTransferToken_remembersSitesWithoutIdServiceLogin() async throws {
        let error = tokenError(TransferTokenExchange.invalidTarget)
        response = { throw error }
        let exchange = makeExchange()

        _ = try await exchange.transferToken(resource: siteUrl)
        _ = try await exchange.transferToken(resource: URL(string: "https://www.site.se/other/")!)

        XCTAssertEqual(requests.count, 1)
    }

    func testTransferToken_remembersAudiencesWithoutAClient() async throws {
        let error = tokenError(TransferTokenExchange.invalidTarget)
        response = { throw error }
        let exchange = makeExchange()

        _ = try await exchange.transferToken(audience: "unknown-client")
        _ = try await exchange.transferToken(audience: "unknown-client")

        XCTAssertEqual(requests.count, 1)
    }

    func testTransferToken_asksAgainOnceASiteWithoutLoginHasExpired() async throws {
        let error = tokenError(TransferTokenExchange.invalidTarget)
        response = { throw error }
        let exchange = makeExchange()

        _ = try await exchange.transferToken(resource: siteUrl)
        time = time.addingTimeInterval(TransferTokenExchange.targetWithoutLoginTTL + 1)
        _ = try await exchange.transferToken(resource: siteUrl)

        XCTAssertEqual(requests.count, 2)
    }

    func testTransferToken_whenExchangeFails_shouldThrowAndAskAgainNextTime() async throws {
        let error = tokenError("invalid_grant")
        response = { throw error }
        let exchange = makeExchange()

        do {
            _ = try await exchange.transferToken(resource: siteUrl)
            XCTFail("Should throw")
        } catch {}
        _ = try? await exchange.transferToken(resource: siteUrl)

        XCTAssertEqual(requests.count, 2)
    }

    func testTransferToken_whenIdServiceIsTooSlow_shouldReturnNil() async throws {
        response = {
            try await Task.sleep(nanoseconds: 10_000_000_000)
            return "transferToken"
        }

        let token = try await makeExchange(timeout: 0.1).transferToken(resource: siteUrl)

        XCTAssertNil(token)
    }
}
