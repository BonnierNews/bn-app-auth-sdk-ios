# BNAppAuth SDK

BNAppAuth is an iOS library for handling authentication using the AppAuth library. It provides a simple interface for logging in, logging out, and managing authentication tokens.

## Features
- **Login**: Allows users to authenticate.
- **Account Creation**: Facilitates user registration.
- **Logout**: Log users out.
- **Token Management**: Retrieve and refresh ID tokens.
- **State Management**: Stores and clears authentication state securely.

## Setup
The module is imported with Swift Package Manager.

## Initialization
To use the SDK, you need to first configure it.
```
let client = BNAppAuth.ClientConfiguration(
    issuer: URL(string: "https://oidc-server-url")!,
    clientId: "client-id",
    clientSecret: nil,
    loginRedirectURL: URL(string: "login-callback-url")!,
    logoutRedirectUrl: URL(string: "logout-callback-url")!,
    isDebuggable: true, // Enable for debugging
    customScopes: ["custom-scope"], // Optional
    useMigration: false, // Defaults to false, set to true to migrate uses from issuer /oidc to /oauth
)
BNAppAuth.shared.configure(client: client)
```

## Methods

```
configure(client: ClientConfiguration)
```
Configures the client with necessary parameters.
- **Parameters**:
  - `client` (ClientConfiguration): The configuration containing client details like `clientId`, `clientSecret`, and `issuer`.

```
createAccount(completion: ((Result<Void,Error>) -> Void)?)
```
Initiates a login flow with action `create-user` to create an account.
- **Parameters**:
  - `completion` (Closure): Callback executed upon the completion of the login process.

```
login(token: String? = nil, action: String? = nil, completion: ((Result<Void,Error>) -> Void)?)
```
Logs the user into the application.
- **Parameters**:
  - `token` (String?, optional): Token passed to the login request.
  - `action` (String?, optional): Action that the login is associated with.
  - `completion` (Closure): Callback executed upon the completion of the login process.

```
logout(completion: ((Result<Void,Error>) -> Void)?)
```
Logs the user out of the application.
- **Parameters**:
  - `completion` (Closure): Callback executed upon the completion of the logout process.

```
continueAuthorization(_ url: URL) -> Bool
```
Continues the authorization flow by processing the URL passed from the external user agent.
- **Parameters**:
  - `url` (URL): The URL containing authorization response data.
- **Returns**: 
  - `true` if the flow was successfully continued, `false` otherwise.

```
getIdToken(forceRefresh: Bool = false, getLoginToken: Bool = false, completion: @escaping (Result<TokenResponse?,Error>) -> Void)
```
Fetches the ID token, optionally forcing a refresh or requesting a login token.
- **Parameters**:
  - `forceRefresh` (Bool): Whether to force a refresh of the token.
  - `getLoginToken` (Bool): Whether to request a login token (magic link token) in the response.
  - `completion` (Closure): Callback executed with the token response or an error.

```
clearState()
```
Clears the current authentication state.

```
addOnStateChangeListener(_ listener: @escaping StateChangeListener)
```
Adds a listener to be notified whenever the authentication state changes.
- **Parameters**:
  - `listener` (StateChangeListener): Closure to execute when the state changes.
  

## Exampleapp
The exampleapp in `BNAppAuthExampleApp/` is a sample iOS application demonstrating how to use the BNAppAuth library. It includes examples of configuring the library, initiating login and logout processes, and handling authentication tokens.
1. **Configuration**: Setting up the BNAppAuth instance with the necessary client configuration.
2. **Login/Logout**: Initiating the login and logout processes and handling the result.
3. **Force Refresh**: Forcing a token refresh via `getIdToken(forceRefresh: true)`.
4. **Get Login Token**: Fetching a magic link login token via `getIdToken(getLoginToken: true)`.
5. **Exchange Token / Test Migration**: Resets the `BnMigrationCompleted` flag in UserDefaults, allowing you to re-trigger the migration flow. Use this button to test that the migration from `/oidc` to `/oauth` works correctly without needing to reinstall the app.

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
