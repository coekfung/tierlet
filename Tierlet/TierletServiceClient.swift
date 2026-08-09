import Combine
import Foundation
import ServiceManagement

@MainActor
final class TierletServiceClient: ObservableObject {
    @Published private(set) var status = "Helper not installed"
    @Published private(set) var serviceStatus: TierletServiceStatus?

    private var connection: NSXPCConnection?

    func refreshStatus() {
        switch SMAppService.daemon(plistName: TierletServiceIdentity.plistName).status {
        case .enabled:
            status = "Helper installed"
            fetchStatus()
        case .requiresApproval:
            status = "Helper requires approval in System Settings"
            serviceStatus = nil
        case .notFound:
            status = "Helper configuration not found"
            serviceStatus = nil
        case .notRegistered:
            status = "Helper not installed"
            serviceStatus = nil
        @unknown default:
            status = "Unknown helper status"
            serviceStatus = nil
        }
    }

    func install() {
        do {
            try SMAppService.daemon(plistName: TierletServiceIdentity.plistName).register()
            refreshStatus()
        } catch {
            status = "Installation failed: \(error.localizedDescription)"
        }
    }

    func uninstall() {
        SMAppService.daemon(plistName: TierletServiceIdentity.plistName).unregister { [weak self] error in
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
                self?.serviceStatus = status
                self?.status = "Helper installed — EasyTier \(status.easyTierVersion)"
                    + (status.coreReady ? " (core ready)" : " (core not ready)")
            }
        }
    }

    /// Returns the validated remote daemon proxy, updating `status` on failure.
    private func daemonProxy() -> TierletServiceProtocol? {
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

        guard let daemon = proxy as? TierletServiceProtocol else {
            status = "Invalid helper connection"
            return nil
        }
        return daemon
    }

    private func makeConnection() throws -> NSXPCConnection {
        let connection = NSXPCConnection(
            machServiceName: TierletServiceIdentity.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: TierletServiceProtocol.self)
        connection.setCodeSigningRequirement(
            try TierletCodeSigning.sameTeamRequirement(for: TierletServiceIdentity.daemonIdentifier)
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

    isolated deinit {
        connection?.invalidate()
    }
}
