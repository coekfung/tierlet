import Foundation
import Darwin

final class DaemonService: NSObject, TierletDaemonProtocol {
    func ping(withReply reply: @escaping (String) -> Void) {
        reply("tierletd is running (core ABI \(tierletCoreAbiVersion()))")
    }
}

final class DaemonListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = DaemonService()

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: TierletDaemonProtocol.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}

let delegate = DaemonListenerDelegate()
let listener = NSXPCListener(machServiceName: TierletService.machServiceName)

do {
    listener.setConnectionCodeSigningRequirement(
        try TierletCodeSigning.sameTeamRequirement(for: TierletService.appIdentifier)
    )
    listener.delegate = delegate
    listener.resume()
    RunLoop.main.run()
} catch {
    let message = "tierletd refused to start: \(error)\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(EXIT_FAILURE)
}
