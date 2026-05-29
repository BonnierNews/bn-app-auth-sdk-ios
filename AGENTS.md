# AGENTS.md — BNAppAuth (iOS)

Guidance for AI agents working in `bn-app-auth-sdk-ios`. Read this first, then the
`README.md` for the public API surface.

## What this is

`BNAppAuth` is a Swift Package that wraps [openid/AppAuth-iOS] to give Bonnier News
apps a small OIDC/OAuth client: login, account creation, logout, ID-token retrieval/
refresh, and secure auth-state storage. It is consumed via Swift Package Manager by
the host apps; this repo also contains a UIKit example app for manual testing.

## Layout

```
Package.swift                 # SPM manifest — library product "BNAppAuth", iOS 11+
Sources/BNAppAuth/
  BNAppAuth.swift             # Public singleton `BNAppAuth.shared` — the whole API
  Models/ClientConfiguration.swift
  Definitions/               # TokenResponse, Errors, UserDefaultKeys, +Globals (flow builders, protocols)
  Protocols/Testable.swift   # Seams over OIDAuthorizationService / OIDAuthState for mocking
  Helpers/                   # Logger, JWTDecoder
  AuthStorage/               # AuthStorage (Keychain-backed) + KeychainWrapper + Constants
Tests/BNAppAuthTests/        # XCTest unit tests + Mocks/ for every injected protocol
BNAppAuthExampleApp/         # Standalone UIKit sample app (.xcodeproj) — see README for buttons
.github/workflows/BNAppAuthCITests.yml
```

## Build & test

The package itself is the unit of work — run commands from the repo root.

```sh
swift build                  # compile the library
xcodebuild test -scheme BNAppAuth \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'
```

CI (`BNAppAuthCITests.yml`) runs `xcodebuild test` on `macos-latest` for PRs against
`main` and `feature/**`. Match the destination CI uses, or the nearest installed
simulator (`xcrun simctl list devices`). `swift test` alone will not work for the
parts that need UIKit/a simulator.

## Architecture notes

- **Single entry point:** everything goes through `BNAppAuth.shared`. Call
  `configure(client:)` with a `ClientConfiguration` before anything else.
- **Dependency injection for testing:** `BNAppAuth.init` takes `authStorage`,
  `authService`, `authFlowBuilder`, and `userDefaults`, all defaulted. Tests inject
  the mocks in `Tests/BNAppAuthTests/Mocks/`. The `Testable*` protocols in
  `Protocols/Testable.swift` and the flow-builder protocols in
  `Definitions/BNAppAuth+Globals.swift` exist purely as test seams — preserve them
  when refactoring.
- **State storage:** `OIDAuthState` is archived into the Keychain via
  `AuthStorage`/`KeychainWrapper`. The in-memory `authState` `didSet` is the single
  place that persists state, clears it, and fires `onStateChangeListeners` — route
  all state mutations through `setAuthState(_:)`, not by writing the Keychain directly.
- **Concurrency:** token access is guarded by `tokenMutex` (`NSLock`) and an
  `isolationQueue`. Keep new token reads/writes behind these.
- **Migration:** when `ClientConfiguration.useMigration == true`, the SDK migrates
  users from the issuer's `/oidc` to `/oauth`, tracked by the `BnMigrationCompleted`
  UserDefaults flag. The example app's "Exchange Token / Test Migration" button
  resets this flag for re-testing.
- **URL callback:** the host app must forward the redirect URL into
  `continueAuthorization(_:)` for the flow to complete.

## Conventions

- Public API changes must stay in sync with `README.md` (it documents every method).
- New injected collaborators should follow the existing pattern: a protocol + a
  default concrete factory in `+Globals.swift` + a mock under `Tests/.../Mocks/`.
- `.DS_Store`, `.swiftpm`, `xcuserdata`, and `.build` are git-ignored — don't commit them.
- Don't commit real client IDs/secrets or issuer URLs; those belong to the host app's config.

[openid/AppAuth-iOS]: https://github.com/openid/AppAuth-iOS
