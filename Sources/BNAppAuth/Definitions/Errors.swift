import Foundation

enum BNAppAuthError: Error {
    case clientNotConfigured
    case oidcConfigurationNotFound
    case oidcCallbackFailedWithUnknownError
    case couldNotCreateUserAgent
}
