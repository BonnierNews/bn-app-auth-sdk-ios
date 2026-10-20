//
//  AppDelegate.swift
//  BNAppAuthExample
//
//  Created by Robin Bonin (BN) on 2023-06-13.
//

import UIKit
import BNAppAuth

// Dummy values: fill in a site and a client id that id-service issues transfer tokens for.
enum TransferTokenTest {
    static let resource = URL(string: "https://www.example.com/")!
    static let audience = "site-client-id"
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Dummy values: fill in a real issuer, client and redirect URLs to run the example app, but don't commit them.
        let client = BNAppAuth.ClientConfiguration(
            issuer: URL(string: "https://oidc-provider.com/")!,
            clientId: "client-id",
            clientSecret: nil,
            loginRedirectURL: URL(string: "custom.redirect.scheme://www.test.se/login")!,
            logoutRedirectUrl: URL(string: "custom.redirect.scheme://www.test.se/logout")!,
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
