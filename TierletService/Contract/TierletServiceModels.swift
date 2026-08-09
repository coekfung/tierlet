import Foundation

/// Snapshot of the privileged service state transported across XPC.
@objc(TierletServiceStatus)
nonisolated final class TierletServiceStatus: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    let coreReady: Bool
    let easyTierVersion: String

    init(coreReady: Bool, easyTierVersion: String) {
        self.coreReady = coreReady
        self.easyTierVersion = easyTierVersion
    }

    func encode(with coder: NSCoder) {
        coder.encode(coreReady, forKey: "coreReady")
        coder.encode(easyTierVersion, forKey: "easyTierVersion")
    }

    required init?(coder: NSCoder) {
        coreReady = coder.decodeBool(forKey: "coreReady")
        guard let easyTierVersion = coder.decodeObject(
            of: NSString.self, forKey: "easyTierVersion") as String?
        else {
            return nil
        }
        self.easyTierVersion = easyTierVersion
    }
}
