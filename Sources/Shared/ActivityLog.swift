import Foundation

/// A log every process writes to. Entries go to two places: a short list for the
/// Diagnostics screen, and debug-log.txt in the App Group, which keeps the full history.
enum ActivityLog {
    struct Entry: Codable, Identifiable, Equatable {
        var id = UUID()
        var at: Date
        var source: String
        var text: String
    }

    private static let key = "log.v1"
    private static let maxEntries = 300

    static func add(_ text: String) {
        let entry = Entry(at: Date(), source: source, text: text)
        var entries = all()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        if let data = try? JSONEncoder().encode(entries) {
            AppGroup.defaults.set(data, forKey: key)
        }
        appendToTextFile(entry)
    }

    static func all() -> [Entry] {
        guard let data = AppGroup.defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: key)
        if let url = textFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: Text file

    static var textFileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent("debug-log.txt")
    }

    static func line(for entry: Entry) -> String {
        "\(timestamp(entry.at))  [\(entry.source)]  \(entry.text)\n"
    }

    /// The whole text log, oldest first.
    static func textLog() -> String {
        guard let url = textFileURL,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }

    /// Keeps the file under about a megabyte by dropping the oldest half.
    /// Only the app calls this, so it never races an extension mid-write.
    static func trimTextFile() {
        guard let url = textFileURL,
              let data = try? Data(contentsOf: url),
              data.count > 1_000_000 else { return }
        var tail = data.suffix(500_000)
        if let newline = tail.firstIndex(of: 0x0A) {
            tail = tail[tail.index(after: newline)...]
        }
        try? Data(tail).write(to: url, options: .atomic)
    }

    /// O_APPEND makes each line one atomic write, so the app and the
    /// extensions can log at the same time without clobbering each other.
    private static func appendToTextFile(_ entry: Entry) {
        guard let url = textFileURL, let data = line(for: entry).data(using: .utf8) else { return }
        let fd = open(url.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard fd >= 0 else { return }
        defer { close(fd) }
        data.withUnsafeBytes { buffer in
            _ = write(fd, buffer.baseAddress, buffer.count)
        }
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private static var source: String {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        if bundleID.hasSuffix(".LimitMonitor") { return "Monitor" }
        if bundleID.hasSuffix(".ShieldButtons") { return "Lock screen buttons" }
        if bundleID.hasSuffix(".ShieldLook") { return "Lock screen" }
        return "App"
    }
}
