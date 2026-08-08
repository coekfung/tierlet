import Foundation
import Darwin

final class DaemonService: NSObject, TierletDaemonProtocol {
    func ping(withReply reply: @escaping (String) -> Void) {
        reply("tierletd is running (core ABI \(tierletCoreAbiVersion()))")
    }

    func status(withReply reply: @escaping (TierletDaemonStatus) -> Void) {
        let status = runtimeStatus()
        reply(TierletDaemonStatus(
            coreReady: status.initialized,
            easyTierVersion: status.easyTierVersion
        ))
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

/// Destroys the EasyTier runtime, then exits. Called from the signal handlers
/// so launchd stops (SIGTERM) and manual Ctrl+C runs (SIGINT) clean up first.
func destroyAndExit() -> Never {
    try? destroyRuntime()
    exit(EXIT_SUCCESS)
}

// Initialize the EasyTier runtime before accepting connections. Fail fast so
// the failure is visible in the launchd logs instead of a half-working daemon.
do {
    try initializeRuntime()
} catch {
    let message = "tierletd failed to initialize EasyTier runtime: \(error)\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(EXIT_FAILURE)
}

let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigtermSource.setEventHandler { destroyAndExit() }
sigtermSource.resume()
signal(SIGTERM, SIG_IGN)

let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigintSource.setEventHandler { destroyAndExit() }
sigintSource.resume()
signal(SIGINT, SIG_IGN)

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
