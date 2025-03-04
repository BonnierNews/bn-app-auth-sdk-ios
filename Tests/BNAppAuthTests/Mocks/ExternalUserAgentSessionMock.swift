import AppAuth
import Foundation

class ExternalUserAgentSessionMock: NSObject, OIDExternalUserAgentSession {
    var cancelInvokeCount = 0
    var cancelWasCalled: ((Int) -> Void)?
    func cancel() {
        cancelInvokeCount += 1
        cancelWasCalled?(cancelInvokeCount)
    }
    
    var cancelWithCompletionInvokeCount = 0
    var cancelWithCompletionWasCalled: ((Int) -> Void)?
    var cancelWithCompletionLastCompletion: (() -> Void)?
    func cancel(completion: (() -> Void)?) {
        cancelWithCompletionLastCompletion = completion
        cancelWithCompletionInvokeCount += 1
        cancelWithCompletionWasCalled?(cancelWithCompletionInvokeCount)
    }

    var resumeExternalUserAgentFlowInvokeCount = 0
    var resumeExternalUserAgentFlowWasCalled: ((Int) -> Void)?
    var resumeExternalUserAgentFlowLastUrl: URL?
    var resumeExternalUserAgentFlowReturnValue = false
    func resumeExternalUserAgentFlow(with URL: URL) -> Bool {
        resumeExternalUserAgentFlowLastUrl = URL
        resumeExternalUserAgentFlowInvokeCount += 1
        resumeExternalUserAgentFlowWasCalled?(resumeExternalUserAgentFlowInvokeCount)
        return resumeExternalUserAgentFlowReturnValue
    }
    
    var failExternalUserAgentFlowWithErrorInvokeCount = 1
    var failExternalUserAgentFlowWithErrorWasCalled: ((Int) -> Void)?
    var failExternalUserAgentFlowWithErrorLastError: Error?
    func failExternalUserAgentFlowWithError(_ error: Error) {
        failExternalUserAgentFlowWithErrorLastError = error
        failExternalUserAgentFlowWithErrorInvokeCount += 1
        failExternalUserAgentFlowWithErrorWasCalled?(failExternalUserAgentFlowWithErrorInvokeCount)
    }
    
}
