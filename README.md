# BNAppAuth for iOS

BNAppAuth is the Bonnier News login SDK for iOS. It wraps [AppAuth-iOS](https://github.com/openid/AppAuth-iOS) and gives the apps one place for everything that talks to id-service: logging in and out, creating accounts, keeping tokens fresh, and handing out transfer tokens that log the user in on other sites.

- [Requirements](#requirements)
- [Installation](#installation)
- [Getting started](#getting-started)
- [Configuration](#configuration)
- [Logging in and out](#logging-in-and-out)
- [ID tokens](#id-tokens)
- [Transfer tokens](#transfer-tokens)
- [Authentication state](#authentication-state)
- [Migrating from /oidc to /oauth](#migrating-from-oidc-to-oauth)
- [Example app](#example-app)
- [License](#license)

## Requirements

- iOS 15 or later
- Swift Package Manager

## Installation

Add the package to your project in Xcode (**File → Add Package Dependencies…**) or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/BonnierNews/bn-app-auth-sdk-ios", from: "<version>")
]
```

Then add the `BNAppAuth` product to your target and `import BNAppAuth`.

## Getting started

Configure the SDK once, early in the app's life, and give it a view controller to present the login and logout pages from:

```swift
let client = BNAppAuth.ClientConfiguration(
    issuer: URL(string: "https://id.bonniernews.se/oauth")!,
    clientId: "your-client-id",
    loginRedirectURL: URL(string: "your-app://login-callback")!,
    logoutRedirectUrl: URL(string: "your-app://logout-callback")!
)

BNAppAuth.shared.configure(client: client)
BNAppAuth.shared.delegate = rootViewController
```

Pass the redirect URL on to the SDK when the app is opened with it, for example from your `SceneDelegate`:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    _ = BNAppAuth.shared.continueAuthorization(url)
}
```

## Configuration

`BNAppAuth.ClientConfiguration` takes the following arguments, in this order:

| Argument | Default | Description |
|---|---|---|
| `issuer` | – | The id-service issuer URL. |
| `clientId` | – | The app's OAuth client id. |
| `clientSecret` | `nil` | The client secret, for clients that have one. |
| `prompt` | `"select_account consent"` | The `prompt` sent with the login request. |
| `loginRedirectURL` | – | Where id-service sends the user after logging in. |
| `logoutRedirectUrl` | – | Where id-service sends the user after logging out. |
| `useCustomBrowser` | `false` | Opens the login page in the Safari app instead of an in-app browser session. |
| `customScopes` | `nil` | Extra scopes besides `openid`. Add `old_bnidtoken` to also get the legacy `bnIdToken`. |
| `isDebuggable` | `false` | Kept for parity with the Android SDK. It has no effect on iOS. |
| `useMigration` | `false` | Moves logged-in users from the old `/oidc` issuer to `/oauth`. See [Migrating from /oidc to /oauth](#migrating-from-oidc-to-oauth). |

All requests to id-service time out after 5 seconds.

## Logging in and out

`login` and `logout` present id-service's pages from `delegate`, so set it first. Without a configured client and a `delegate`, both complete with an error straight away.

```swift
BNAppAuth.shared.login { result in
    switch result {
    case .success: // The user is logged in.
    case .failure(let error): // The login failed or was cancelled.
    }
}
```

| Method | Description |
|---|---|
| `login(token:action:locale:consentId:completion:)` | Starts the login flow. All arguments are optional: `token` logs the user in with a login token, `action` is passed to id-service (for example `create-user`), `locale` sets the language of the login page, and `consentId` passes on the user's consent. |
| `createAccount(locale:consentId:completion:)` | Starts the login flow on the create account page. |
| `logout(completion:)` | Ends the session at id-service and clears the stored state. It only fails if the user cancels. Other errors still log the user out locally. |
| `continueAuthorization(_ url:) -> Bool` | Finishes a login or logout when the app is opened with a redirect URL. Returns `false` if the URL wasn't for an ongoing flow. |

## ID tokens

```swift
BNAppAuth.shared.getIdToken { result in
    switch result {
    case .success(let tokenResponse): // nil when the user is logged out
    case .failure(let error):
    }
}
```

`getIdToken(forceRefresh:getLoginToken:completion:)` returns the current ID token, refreshing the tokens first when needed. While the tokens are valid for more than another minute, it answers without a network call.

- `forceRefresh: true` always refreshes and asks id-service to bypass its cache.
- `getLoginToken: true` refreshes and also returns a login token in `loginToken`.

`BNAppAuth.TokenResponse` contains:

| Property | Description |
|---|---|
| `idToken` | The ID token. |
| `bnIdToken` | The legacy token, when `customScopes` contains `old_bnidtoken`. |
| `isUpdated` | `true` when the ID token changed since the last call. |
| `loginToken` | A login token, when asked for with `getLoginToken`. |

## Transfer tokens

A transfer token is a short-lived token that logs the user in on another site in the same session as the app. The SDK exchanges the user's access token for one at id-service. It never changes the user's own tokens.

There is one method for each kind of target:

```swift
// Web views: the id-service client id of the site.
let token = try await BNAppAuth.shared.getTransferToken(audience: "site-client-id")

// External browsers: the URL that is about to open.
if let token = try await BNAppAuth.shared.getTransferToken(resource: url),
   var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
    components.queryItems = (components.queryItems ?? []) + [
        URLQueryItem(name: BNAppAuth.transferTokenParameter, value: token)
    ]
    url = components.url ?? url
}
```

Add the token to the URL as `BNAppAuth.transferTokenParameter` (`idtransfertoken`). The site exchanges it for its own login.

- **A nil token** means there is no token to add right now. Open the URL as it is. That happens when:
  - the user is logged out,
  - id-service has no client for the audience or site (it answers `invalid_target`, and the SDK then skips that audience or site for 24 hours), or
  - id-service didn't answer within 2 seconds.
- **A thrown error** means the exchange failed. Open the URL as it is. The next call tries again.
- **Only https URLs** get a token, since the token ends up in the URL the browser opens.

## Authentication state

| Member | Description |
|---|---|
| `isAuthorized` | Whether the user is logged in. |
| `addOnStateChangeListener(_:)` | Calls the listener with the new `isAuthorized` value whenever the state changes. |
| `clearState()` | Removes the stored state, which logs the user out locally without contacting id-service. |
| `releaseResources()` | Does nothing on iOS. It exists for parity with the Android SDK. |

The state is stored in the Keychain.

## Migrating from /oidc to /oauth

With `useMigration: true`, the first `getIdToken` call after an update exchanges the token from the old `/oidc` issuer for new `/oauth` tokens. It only runs once. If the exchange fails, the user is logged out. `exchangeIdToken(oldIdToken:newExchangeEndpoint:completion:)` is the public method that performs this exchange.

## Example app

`BNAppAuthExampleApp/` is a UIKit app for trying the SDK by hand:

1. **Configuration**: sets up `BNAppAuth` with a client configuration.
2. **Login and logout**: starts the flows and shows the result.
3. **Force refresh**: calls `getIdToken(forceRefresh: true)`.
4. **Get login token**: calls `getIdToken(getLoginToken: true)`.
5. **Exchange token / test migration**: resets the `BnMigrationCompleted` flag in `UserDefaults`, so the migration from `/oidc` to `/oauth` runs again without reinstalling the app.
6. **Transfer token (resource / audience)**: calls `getTransferToken(resource:)` or `getTransferToken(audience:)` and shows the token, "No token" or the error.

The client configuration and the site and client id the transfer token buttons use come from `BNAppAuthExample/Example.xcconfig`, which holds dummy values. To run the app against a real environment, copy `BNAppAuthExample/.env.xcconfig.sample` to `.env.xcconfig` in the same folder and fill in your values. The file is git-ignored, so it never gets committed. In xcconfig files `//` starts a comment, so write urls with `:/$()/` instead of `://`.

## License

MIT License

Copyright (c) 2025 Bonnier News AB

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
