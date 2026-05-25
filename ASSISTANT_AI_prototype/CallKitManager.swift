import Foundation
import CallKit

final class CallKitManager: NSObject {
    static let shared = CallKitManager()

    private let provider: CXProvider
    private let controller = CXCallController()

    override init() {
        let config = CXProviderConfiguration(localizedName: "AST AI")
        config.supportsVideo = false
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.phoneNumber]
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func reportIncomingCall(uuid: UUID, handle: String, completion: ((Error?) -> Void)? = nil) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber, value: handle)
        update.hasVideo = false
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            completion?(error)
        }
    }

    func startCall(handle: String, completion: @escaping (Bool) -> Void) {
        let handle = CXHandle(type: .phoneNumber, value: handle)
        let start = CXStartCallAction(call: UUID(), handle: handle)
        let transaction = CXTransaction(action: start)
        controller.request(transaction) { error in
            completion(error == nil)
        }
    }

    func endCall(uuid: UUID) {
        let end = CXEndCallAction(call: uuid)
        let tx = CXTransaction(action: end)
        controller.request(tx, completion: { _ in })
    }
}

extension CallKitManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {}
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
    }
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
    }
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: nil)
        action.fulfill()
    }
}
