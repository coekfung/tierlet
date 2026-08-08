import Foundation
import Security

enum TierletService {
    static let appIdentifier = "wang.coekfung.tierlet"
    static let daemonIdentifier = "wang.coekfung.tierlet.daemon"
    static let machServiceName = daemonIdentifier
    static let plistName = "\(daemonIdentifier).plist"
}

@objc(TierletDaemonProtocol)
protocol TierletDaemonProtocol {
    func ping(withReply reply: @escaping (String) -> Void)
    func status(withReply reply: @escaping (TierletDaemonStatus) -> Void)
}

/// Snapshot of the daemon's core state, mirrored from TierletCore.runtimeStatus().
/// NSSecureCoding so it can cross the @objc XPC boundary.
@objc(TierletDaemonStatus)
final class TierletDaemonStatus: NSObject, NSSecureCoding {
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

enum TierletCodeSigning {
    enum Error: Swift.Error, LocalizedError {
        case cannotReadSelf(OSStatus)
        case cannotReadStaticCode(OSStatus)
        case cannotReadSigningInformation(OSStatus)
        case missingTeamIdentifier

        var errorDescription: String? {
            switch self {
            case let .cannotReadSelf(status):
                "Unable to read this process's code signature (OSStatus \(status))."
            case let .cannotReadStaticCode(status):
                "Unable to inspect this process's code signature (OSStatus \(status))."
            case let .cannotReadSigningInformation(status):
                "Unable to read this process's signing information (OSStatus \(status))."
            case .missingTeamIdentifier:
                "This build has no Apple Developer Team ID. Sign both the app and helper with the same Apple Developer certificate."
            }
        }
    }

    static func sameTeamRequirement(for identifier: String) throws -> String {
        var code: SecCode?
        let selfStatus = SecCodeCopySelf([], &code)
        guard selfStatus == errSecSuccess, let code else {
            throw Error.cannotReadSelf(selfStatus)
        }

        var staticCode: SecStaticCode?
        let staticCodeStatus = SecCodeCopyStaticCode(code, [], &staticCode)
        guard staticCodeStatus == errSecSuccess, let staticCode else {
            throw Error.cannotReadStaticCode(staticCodeStatus)
        }

        var information: CFDictionary?
        let informationStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        )
        guard informationStatus == errSecSuccess,
              let values = information as? [String: Any] else {
            throw Error.cannotReadSigningInformation(informationStatus)
        }

        guard let teamIdentifier = values[kSecCodeInfoTeamIdentifier as String] as? String,
              !teamIdentifier.isEmpty else {
            throw Error.missingTeamIdentifier
        }

        return "anchor apple generic and identifier \"\(identifier)\" "
            + "and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
    }
}
