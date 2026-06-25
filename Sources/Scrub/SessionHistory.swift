import Foundation
import os

private let log = Logger(subsystem: "com.nuttapongpun.scrub", category: "SessionHistory")

/// How a recorded session ended (ADR-0007 / CONTEXT.md `endedBy`). Deliberately a *subset* of
/// `EndReason`: the `manual` Quit/menu-stop escape hatch is not a logged cleaning exit. Keep
/// this enum in sync with the genuine session-end causes (see `EndReason.historyCause`). The
/// raw values are the persisted, ISO-stable strings — don't rename without migrating the log.
enum SessionEndCause: String, Codable {
    case chord
    case forceEnd
    case failOpen
}

/// One completed cleaning session (ADR-0007). `start` is encoded ISO-8601, `duration` is in
/// seconds, `endedBy` is the genuine exit cause.
struct SessionRecord: Codable {
    let start: Date
    let duration: TimeInterval
    let endedBy: SessionEndCause
}

/// Append-only session history (ADR-0007), persisted as a JSON array at
/// `~/Library/Application Support/Scrub/history.json`. Written once per completed session and
/// read on demand to populate the "History…" menu. JSON (not a DB) is inspectable and trivial
/// for a personal log; a retention cap is a future concern (ADR-0007, open question).
struct SessionHistory {

    private let fileURL: URL
    private let fileManager: FileManager

    /// Defaults to `<Application Support>/Scrub/history.json`. Injectable for tests.
    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = base
                .appendingPathComponent("Scrub", isDirectory: true)
                .appendingPathComponent("history.json")
        }
    }

    /// All recorded sessions, oldest first. Returns empty if the log is missing or unreadable —
    /// history is best-effort and never blocks a clean.
    func records() -> [SessionRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            return try Self.decoder.decode([SessionRecord].self, from: data)
        } catch {
            log.error("Failed to decode history: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    /// Appends one completed session to the log, creating the directory/file as needed.
    /// Best-effort: a write failure is logged, not surfaced — it must never disrupt unlocking.
    func append(_ record: SessionRecord) {
        var all = records()
        all.append(record)
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try Self.encoder.encode(all)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log.error("Failed to append history: \(String(describing: error), privacy: .public)")
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
