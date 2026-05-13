import Foundation

/// Streaming JSONL reader that tail-follows a file.
/// Reads new lines as they are appended, similar to `tail -f`.
final class JSONLReader {
    private let fileURL: URL
    private var lastOffset: UInt64 = 0
    private let queue = DispatchQueue(label: "jsonl-reader")

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Read all new lines since the last read.
    /// Returns array of parsed JSON dictionaries.
    func readNewLines() -> [[String: Any]] {
        var results: [[String: Any]] = []

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return results
        }

        defer { try? handle.close() }

        // Seek to last known position
        handle.seek(toFileOffset: lastOffset)
        let data = handle.readDataToEndOfFile()

        guard !data.isEmpty else { return results }

        lastOffset += UInt64(data.count)

        guard let text = String(data: data, encoding: .utf8) else {
            return results
        }

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if let jsonData = trimmed.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                results.append(json)
            }
        }

        return results
    }

    /// Seek to end of file (skip existing content, only read new lines)
    func seekToEnd() {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return }
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        lastOffset = handle.offsetInFile
    }

    /// Reset to beginning
    func reset() {
        lastOffset = 0
    }
}
