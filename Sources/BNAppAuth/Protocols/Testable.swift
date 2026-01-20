//
//  File.swift
//  
//
//  Created by Robin Bonin (BN) on 2023-09-29.
//

import AppAuth
import Foundation

public protocol TestableOIDAuthorizationService {
    static func discoverConfiguration(forIssuer issuerURL: URL, completion: @escaping OIDDiscoveryCallback)
    static func perform(
        _ request: OIDTokenRequest,
        callback: @escaping @Sendable OIDTokenCallback
    )
}

extension OIDAuthorizationService: TestableOIDAuthorizationService {}

public protocol TestableAuthState: AnyObject {
    var stateChangeDelegate: OIDAuthStateChangeDelegate? { get set }
    func setNeedsTokenRefresh()
    func performAction(freshTokens action: @escaping OIDAuthStateAction, additionalRefreshParameters additionalParameters: [String : String]?)
    var isAuthorized: Bool { get }
    var lastTokenResponse: OIDTokenResponse? { get }
    var refreshToken: String? { get }
}

extension OIDAuthState: TestableAuthState {}
