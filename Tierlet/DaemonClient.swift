import Combine
import Foundation
import ServiceManagement

@MainActor
final class DaemonClient: ObservableObject {
    @Published private(set) var status = "Helper not installed"
    @Published private(set) var daemonStatus: TierletDaemonStatus?

    private var connection: NSXPCConnection?

    func refreshStatus() {
        switch SMAppService.daemon(plistName: TierletService.plistName).status {
        case .enabled:
            status = "Helper installed"
            fetchStatus()
        case .requiresApproval:
            status = "Helper requires approval in System Settings"
            daemonStatus = nil
        case .notFound:
            status = "Helper configuration not found"
            daemonStatus = nil
        case .notRegistered:
            status = "Helper not installed"
            daemonStatus = nil
        @unknown default:
            status = "Unknown helper status"
            daemonStatus = nil
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

    func uninstall() {
        SMAppService.daemon(plistName: TierletService.plistName).unregister { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.connection?.invalidate()
                self.connection = nil
                if let error {
                    self.status = "Uninstallation failed: \(error.localizedDescription)"
                } else {
                    self.status = "Helper uninstalled"
                }
            }
        }
    }

    func ping() {
        guard let daemon = daemonProxy() else { return }
        daemon.ping { [weak self] response in
            Task { @MainActor in
                self?.status = response
            }
        }
    }

    func fetchStatus() {
        guard let daemon = daemonProxy() else { return }
        daemon.status { [weak self] status in
            Task { @MainActor in
                self?.daemonStatus = status
                self?.status = "Helper installed — EasyTier \(status.easyTierVersion)"
                    + (status.coreReady ? " (core ready)" : " (core not ready)")
            }
        }
    }

    /// Returns the validated remote daemon proxy, updating `status` on failure.
    private func daemonProxy() -> TierletDaemonProtocol? {
        let connection: NSXPCConnection
        do {
            connection = try self.connection ?? makeConnection()
        } catch {
            status = "Cannot validate helper: \(error.localizedDescription)"
            return nil
        }

        let proxy = connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            Task { @MainActor in
                self?.status = "Helper unavailable: \(error.localizedDescription)"
            }
        }

        guard let daemon = proxy as? TierletDaemonProtocol else {
            status = "Invalid helper connection"
            return nil
        }
        return daemon
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
