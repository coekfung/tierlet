import Foundation

final class DaemonService: NSObject, TierletServiceProtocol {
    func ping(withReply reply: @escaping (String) -> Void) {
        reply("tierletd is running (core ABI \(tierletCoreAbiVersion()))")
    }

    func status(withReply reply: @escaping (TierletServiceStatus) -> Void) {
        reply(TierletServiceStatus(coreStatus: runtimeStatus()))
    }
}

private extension TierletServiceStatus {
    convenience init(coreStatus: RuntimeStatus) {
        self.init(
            coreReady: coreStatus.initialized,
            easyTierVersion: coreStatus.easyTierVersion
        )
    }
}
