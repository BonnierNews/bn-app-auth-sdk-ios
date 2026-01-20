//
//  AuthStateMock.swift
//  
//
//  Created by Vincent Palma (BN) on 2023-10-05.
//

import Foundation
import AppAuth
@testable import BNAppAuth

class AuthStateMock: OIDAuthState {
    var _isAuthorized: Bool = true
    override var isAuthorized: Bool {
        _isAuthorized
    }
    
    var _stateChangeDelegate: OIDAuthStateChangeDelegate?
    override var stateChangeDelegate: OIDAuthStateChangeDelegate? {
        get {
            _stateChangeDelegate
        }
        set {
            _stateChangeDelegate = newValue
        }
    }

    var tokenResponseIdTokenReturnValue: String? {
        get {
            (lastTokenResponse as? TokenResponseMock)?.idTokenReturnValue
        }
        set {
            (lastTokenResponse as? TokenResponseMock)?.idTokenReturnValue = newValue
        }
    }
    
    var tokenResponseAdditionalParametersReturnValue: [String: (any NSCopying & NSObjectProtocol)]? {
        get {
            (lastTokenResponse as? TokenResponseMock)?.additionalParametersReturnValue
        }
        set {
            (lastTokenResponse as? TokenResponseMock)?.additionalParametersReturnValue = newValue
        }
    }
    
    lazy var lastTokenResponseReturnValue: OIDTokenResponse? = TokenResponseMock(
        request: OIDTokenRequest(
            configuration: AuthorizationServiceMock.configurationReturnValue,
            grantType: "refresh",
            authorizationCode: nil,
            redirectURL: nil,
            clientID: "clientId",
            clientSecret: nil,
            scope: nil,
            refreshToken: refreshToken,
            codeVerifier: nil,
            additionalParameters: nil
        ),
        parameters: [:]
    )
    override var lastTokenResponse: OIDTokenResponse? {
        lastTokenResponseReturnValue
    }
    
    var setNeedsTokenRefreshWasCalledTimes: ((Int) -> Void)?
    var setNeedsTokenRefreshInvokeCount = 0
    override func setNeedsTokenRefresh() {
        setNeedsTokenRefreshInvokeCount += 1
        setNeedsTokenRefreshWasCalledTimes?(setNeedsTokenRefreshInvokeCount)
    }

    var performActionIdTokenReturnValue: String? = "tokenId"
    var performActionErrorReturnValue: NSError? = nil
    var performActionWasCalledTimes: ((Int) -> Void)?
    var performActionInvokeCount = 0
    override func performAction(freshTokens action: @escaping OIDAuthStateAction, additionalRefreshParameters additionalParameters: [String : String]?) {
        performActionInvokeCount += 1
        performActionWasCalledTimes?(performActionInvokeCount)

        action(nil,performActionIdTokenReturnValue,performActionErrorReturnValue)

    }
}

class TokenResponseMock: OIDTokenResponse {
    var additionalParametersReturnValue: [String: (any NSCopying & NSObjectProtocol)]? = [:]
    override var additionalParameters: [String : (any NSCopying & NSObjectProtocol)]? {
        additionalParametersReturnValue
    }
    
    var idTokenReturnValue: String? = "tokenId"
    override var idToken: String? {
        idTokenReturnValue
    }
}

