import Foundation
import Security

enum TierletCodeSigning {
    enum Error: Swift.Error {
        case cannotReadSelf(OSStatus)
        case cannotReadStaticCode(OSStatus)
        case cannotReadSigningInformation(OSStatus)
        case missingTeamIdentifier
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
