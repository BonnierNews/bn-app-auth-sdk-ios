import Foundation
import OSLog

internal class Logger {
    struct Category {
        let log: OSLog
        
        init(_ category: String) {
            log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: category)
        }
        
        func info(_ message: StaticString, _ args: CVarArg...) {
            let formattedMessage = String(format: message.description, arguments: args)
            os_log("%{public}@", log: log, type: .info, formattedMessage)
        }
        
        func fault(_ message: StaticString, _ args: CVarArg...) {
            let formattedMessage = String(format: message.description, arguments: args)
            os_log("%{public}@", log: log, type: .fault, formattedMessage)
        }
        
        func error(_ message: StaticString, _ args: CVarArg...) {
            let formattedMessage = String(format: message.description, arguments: args)
            os_log("%{public}@", log: log, type: .error, formattedMessage)
        }
        
        func debug(_ message: StaticString, _ args: CVarArg...) {
            let formattedMessage = String(format: message.description, arguments: args)
            os_log("%{public}@", log: log, type: .debug, formattedMessage)
        }
    }
}
