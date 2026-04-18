import Foundation
import AppKit

/// Represents a currently mounted external volume.
struct ExternalVolume: Identifiable, Hashable {
    var id: String { uuid }

    let uuid: String
    let name: String
    let mountPath: String
}

/// Enumerates mounted external volumes and checks their connection status.
final class ExternalDriveService {
    static let shared = ExternalDriveService()

    private var cachedExternalVolumes: [ExternalVolume] = []
    private let notificationCenter: NotificationCenter

    private init(notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.notificationCenter = notificationCenter
        refreshCache()
        startObservingVolumeChanges()
    }

    private let resourceKeys: Set<URLResourceKey> = [
        .volumeUUIDStringKey,
        .volumeNameKey,
        .volumeLocalizedNameKey,
        .volumeIsInternalKey,
        .volumeIsLocalKey
    ]

    func listMountedExternalVolumes() -> [ExternalVolume] {
        cachedExternalVolumes
    }

    /// Refresh mounted volume cache immediately.
    @discardableResult
    func refreshCache() -> [ExternalVolume] {
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(resourceKeys),
            options: [.skipHiddenVolumes]
        ) else {
            cachedExternalVolumes = []
            return cachedExternalVolumes
        }

        cachedExternalVolumes = urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: resourceKeys) else { return nil }
            guard (values.volumeIsLocal ?? true) else { return nil }
            guard (values.volumeIsInternal ?? true) == false else { return nil }
            guard let uuid = values.volumeUUIDString, !uuid.isEmpty else { return nil }

            let name = values.volumeLocalizedName ?? values.volumeName ?? url.lastPathComponent
            return ExternalVolume(uuid: uuid, name: name, mountPath: url.path)
        }
        .sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return cachedExternalVolumes
    }

    func isVolumeConnected(uuid: String) -> Bool {
        guard !uuid.isEmpty else { return false }
        return cachedExternalVolumes.contains(where: { $0.uuid == uuid })
    }

    private func startObservingVolumeChanges() {
        notificationCenter.addObserver(
            self,
            selector: #selector(volumesDidChange),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(volumesDidChange),
            name: NSWorkspace.didUnmountNotification,
            object: nil
        )
    }

    @objc private func volumesDidChange(_ notification: Notification) {
        refreshCache()
    }
}
