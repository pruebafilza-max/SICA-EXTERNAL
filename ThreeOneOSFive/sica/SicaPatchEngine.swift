import Foundation
import Darwin

enum SicaPatchError: LocalizedError {
    case gameNotFound
    case accessNotReady
    case payloadMissing(SicaFeature)
    case nothingSelected
    case nothingApplied
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .gameNotFound:
            return "El juego no está instalado o su contenedor no se pudo abrir."
        case .accessNotReady:
            return "El acceso al dispositivo aún no está activo. Espera unos segundos."
        case .payloadMissing(let feature):
            return "Falta el payload de \(feature.title) dentro de la app."
        case .nothingSelected:
            return "Marca al menos una opción."
        case .nothingApplied:
            return "No hay parches aplicados que desactivar."
        case .writeFailed(let path):
            return "No se pudo escribir: \(path)"
        }
    }
}

struct SicaJournalEntry: Codable {
    let game: String
    let feature: SicaFeature
    let target: String
    let backup: String?
    let created: Bool
}

enum SicaPatchEngine {
    private static let fm = FileManager.default

    static var supportDirectory: URL {
        fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sica", isDirectory: true)
    }
    static var backupsDirectory: URL {
        supportDirectory.appendingPathComponent("Backups", isDirectory: true)
    }
    static var journalURL: URL {
        supportDirectory.appendingPathComponent("journal.json")
    }

    private static func ensureDirectories() throws {
        for dir in [supportDirectory, backupsDirectory]
        where !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    static func journal() -> [SicaJournalEntry] {
        guard let data = try? Data(contentsOf: journalURL),
              let entries = try? JSONDecoder().decode([SicaJournalEntry].self, from: data)
        else { return [] }
        return entries
    }

    private static func saveJournal(_ entries: [SicaJournalEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: journalURL, options: .atomic)
    }

    static func appliedFeatures(for game: SicaGame) -> Set<SicaFeature> {
        Set(journal().filter { $0.game == game.bundleID }.map(\.feature))
    }

    static func resolveContainer(for game: SicaGame) -> String? {
        guard let path = ContainerStore.resolveAppContainerPath(bundleID: game.bundleID)
        else { return nil }
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue
        else { return nil }
        return path
    }

    private static func withAccess<T>(to path: String, _ body: () throws -> T) rethrows -> T {
        let handle = ContainerStore.grantContainerAccess(path)
        defer { if handle >= 0 { bad_query_release(handle) } }
        return try body()
    }

    private static func payloadRoot(for feature: SicaFeature) throws -> URL {
        guard let resources = Bundle.main.resourceURL else {
            throw SicaPatchError.payloadMissing(feature)
        }
        let dir = resources
            .appendingPathComponent("SicaPayload", isDirectory: true)
            .appendingPathComponent(feature.payloadFolder, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: dir.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { throw SicaPatchError.payloadMissing(feature) }
        return dir
    }

    private static func payloadPairs(for feature: SicaFeature)
    throws -> [(source: URL, relativePath: String)] {
        let root = try payloadRoot(for: feature)
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { throw SicaPatchError.payloadMissing(feature) }

        var pairs: [(URL, String)] = []
        for case let url as URL in enumerator {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory { continue }
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            pairs.append((url, relative))
        }
        guard !pairs.isEmpty else { throw SicaPatchError.payloadMissing(feature) }
        return pairs
    }

    // MARK: Aplicar

    @discardableResult
    static func apply(
        _ features: Set<SicaFeature>,
        to game: SicaGame,
        progress: (String) -> Void
    ) throws -> Int {
        guard !features.isEmpty else { throw SicaPatchError.nothingSelected }
        guard let container = resolveContainer(for: game) else {
            if KernelExploit.requiresSandboxEscape && !KernelExploit.hasSandboxAccess() {
                throw SicaPatchError.accessNotReady
            }
            throw SicaPatchError.gameNotFound
        }
        try ensureDirectories()

        var entries = journal()
        var written = 0

        try withAccess(to: container) {
            for feature in SicaFeature.allCases where features.contains(feature) {
                if entries.contains(where: { $0.feature == feature && $0.game == game.bundleID }) {
                    continue
                }
                for pair in try payloadPairs(for: feature) {
                    progress("Aplicando \(feature.title) · \(pair.relativePath)")
                    let target = (container as NSString).appendingPathComponent(pair.relativePath)
                    let parent = (target as NSString).deletingLastPathComponent
                    if !fm.fileExists(atPath: parent) {
                        try? fm.createDirectory(atPath: parent, withIntermediateDirectories: true)
                    }

                    let existed = fm.fileExists(atPath: target)
                    var backupName: String?
                    if existed {
                        backupName = UUID().uuidString + "-"
                            + pair.relativePath.replacingOccurrences(of: "/", with: "_")
                        let backupPath = backupsDirectory
                            .appendingPathComponent(backupName!).path
                        try? fm.removeItem(atPath: backupPath)
                        do {
                            try fm.copyItem(atPath: target, toPath: backupPath)
                        } catch {
                            throw SicaPatchError.writeFailed(pair.relativePath)
                        }
                    }

                    do {
                        if existed { try? fm.removeItem(atPath: target) }
                        try fm.copyItem(atPath: pair.source.path, toPath: target)
                        chmod(target, 0o644)
                    } catch {
                        if let backupName,
                           fm.fileExists(atPath: backupsDirectory.appendingPathComponent(backupName).path) {
                            try? fm.copyItem(
                                atPath: backupsDirectory.appendingPathComponent(backupName).path,
                                toPath: target
                            )
                        }
                        throw SicaPatchError.writeFailed(pair.relativePath)
                    }

                    entries.append(
                        SicaJournalEntry(
                            game: game.bundleID,
                            feature: feature,
                            target: pair.relativePath,
                            backup: backupName,
                            created: !existed
                        )
                    )
                    written += 1
                }
            }
        }

        saveJournal(entries)
        return written
    }

    // MARK: Restaurar

    @discardableResult
    static func restoreAll(in game: SicaGame, progress: (String) -> Void) throws -> Int {
        let entries = journal().filter { $0.game == game.bundleID }
        guard !entries.isEmpty else { throw SicaPatchError.nothingApplied }
        guard let container = resolveContainer(for: game) else {
            throw SicaPatchError.gameNotFound
        }

        var restored = 0
        var remaining: [SicaJournalEntry] = []

        try withAccess(to: container) {
            for entry in entries {
                progress("Restaurando \(entry.feature.title) · \(entry.target)")
                let target = (container as NSString).appendingPathComponent(entry.target)
                var ok = true

                if let backup = entry.backup {
                    let backupPath = backupsDirectory.appendingPathComponent(backup).path
                    if fm.fileExists(atPath: backupPath) {
                        try? fm.removeItem(atPath: target)
                        do {
                            try fm.copyItem(atPath: backupPath, toPath: target)
                            chmod(target, 0o644)
                            try? fm.removeItem(atPath: backupPath)
                        } catch {
                            ok = false
                        }
                    }
                } else if entry.created, fm.fileExists(atPath: target) {
                    do { try fm.removeItem(atPath: target) } catch { ok = false }
                }

                if ok { restored += 1 } else { remaining.append(entry) }
            }
        }

        let others = journal().filter { $0.game != game.bundleID }
        saveJournal(others + remaining)
        return restored
    }
}
