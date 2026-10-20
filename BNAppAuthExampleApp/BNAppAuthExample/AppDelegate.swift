//
//  AppDelegate.swift
//  BNAppAuthExample
//
//  Created by Robin Bonin (BN) on 2023-06-13.
//

import UIKit
import BNAppAuth

// The values come from Example.xcconfig and your git-ignored .env.xcconfig, through Info.plist.
enum ExampleConfig {
    static let issuer = url("EXAMPLE_ISSUER")
    static let clientId = value("EXAMPLE_CLIENT_ID")
    static let loginRedirectURL = url("EXAMPLE_LOGIN_REDIRECT_URL")
    static let logoutRedirectURL = url("EXAMPLE_LOGOUT_REDIRECT_URL")
    static let transferTokenResource = url("EXAMPLE_TRANSFER_TOKEN_RESOURCE")
    static let transferTokenAudience = value("EXAMPLE_TRANSFER_TOKEN_AUDIENCE")

    private static func value(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }

    private static func url(_ key: String) -> URL {
        URL(string: value(key))!
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let client = BNAppAuth.ClientConfiguration(
            issuer: ExampleConfig.issuer,
            clientId: ExampleConfig.clientId,
            clientSecret: nil,
            loginRedirectURL: ExampleConfig.loginRedirectURL,
            logoutRedirectUrl: ExampleConfig.logoutRedirectURL,
            customScopes: ["profile", "offline_access", "entitlements", "external_ids", "email", "old_bnidtoken"]
        )
    
        UserDefaults.standard.set(true, forKey: "BnMigrationCompleted")
        BNAppAuth.shared.configure(client: client)
        
        BNAppAuth.shared.addOnStateChangeListener({ isAuthorized in
            if isAuthorized {
                print("\(Self.self) \(#function) should update user entitlements")
            } else {
                print("\(Self.self) \(#function) should use default entitlements")
            }
        })
        
        // Override point for customization after application launch.
        return true
    }

    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if BNAppAuth.shared.continueAuthorization(url) {
            return true
        }
        return false
    }
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}
