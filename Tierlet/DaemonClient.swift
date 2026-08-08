import Combine
import Foundation
import ServiceManagement

@MainActor
final class DaemonClient: ObservableObject {
    @Published private(set) var status = "Helper not installed"

    private var connection: NSXPCConnection?

    func refreshStatus() {
        switch SMAppService.daemon(plistName: TierletService.plistName).status {
        case .enabled:
            status = "Helper installed"
        case .requiresApproval:
            status = "Helper requires approval in System Settings"
        case .notFound:
            status = "Helper configuration not found"
        case .notRegistered:
            status = "Helper not installed"
        @unknown default:
            status = "Unknown helper status"
        }
    }

    func install() {
        do {
            try SMAppService.daemon(plistName: TierletService.plistName).register()
            refreshStatus()
        } catch {
            status = "Installation failed: \(error.localizedDescription)"
        }
    }

    func ping() {
        let connection: NSXPCConnection
        do {
            connection = try self.connection ?? makeConnection()
        } catch {
            status = "Cannot validate helper: \(error.localizedDescription)"
            return
        }

        let proxy = connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            Task { @MainActor in
                self?.status = "Helper unavailable: \(error.localizedDescription)"
            }
        }

        guard let daemon = proxy as? TierletDaemonProtocol else {
            status = "Invalid helper connection"
            return
        }

        daemon.ping { [weak self] response in
            Task { @MainActor in
                self?.status = response
            }
        }
    }

    private func makeConnection() throws -> NSXPCConnection {
        let connection = NSXPCConnection(
            machServiceName: TierletService.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: TierletDaemonProtocol.self)
        connection.setCodeSigningRequirement(
            try TierletCodeSigning.sameTeamRequirement(for: TierletService.daemonIdentifier)
        )
        connection.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
            }
        }
        connection.resume()
        self.connection = connection
        return connection
    }

    deinit {
        connection?.invalidate()
    }
}
