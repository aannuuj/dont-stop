import Foundation

struct TerminalCommand {
    let name: String
    let minutes: Int?
    let reason: String
    let display: Bool?
}


final class StateStore {
    private let directory: URL
    private let stateURL: URL
    private let formatter = ISO8601DateFormatter()

    init(directory: URL = applicationSupportDirectory()) {
        self.directory = directory
        stateURL = directory.appendingPathComponent("state.json", isDirectory: false)
    }

    func write(controller: AwakeController) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            var payload: [String: Any] = [
                "active": controller.isActive,
                "reason": controller.reason,
                "keepDisplayAwake": controller.keepDisplayAwake,
                "updatedAt": formatter.string(from: Date()),
                "pid": Int(ProcessInfo.processInfo.processIdentifier)
            ]

            if let activeUntil = controller.activeUntil {
                payload["until"] = formatter.string(from: activeUntil)
            } else {
                payload["until"] = NSNull()
            }

            if let lastError = controller.lastError {
                payload["lastError"] = lastError
            }

            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: stateURL, options: .atomic)
        } catch {
            NSLog("Don't Stop state write failed: \(error.localizedDescription)")
        }
    }
}

final class CommandInbox {
    private let directory: URL
    private var timer: Timer?

    var onCommand: ((TerminalCommand) -> Void)?

    init(directory: URL = applicationSupportDirectory().appendingPathComponent("commands", isDirectory: true)) {
        self.directory = directory
    }

    func start() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("Don't Stop command directory failed: \(error.localizedDescription)")
        }

        processPendingCommands()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.processPendingCommands()
        }
    }

    private func processPendingCommands() {
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for file in files.filter({ $0.pathExtension == "command" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if let command = parseCommand(at: file) {
                onCommand?(command)
            }
            try? fileManager.removeItem(at: file)
        }
    }

    private func parseCommand(at file: URL) -> TerminalCommand? {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else {
            return nil
        }

        var values: [String: String] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let separator = rawLine.firstIndex(of: "=") else {
                continue
            }
            let key = String(rawLine[..<separator])
            let value = String(rawLine[rawLine.index(after: separator)...])
            values[key] = value
        }

        guard let name = values["command"], !name.isEmpty else {
            return nil
        }

        let reason: String
        if let base64Reason = values["reasonBase64"],
           let data = Data(base64Encoded: base64Reason),
           let decodedReason = String(data: data, encoding: .utf8) {
            reason = decodedReason
        } else {
            reason = values["reason"] ?? "Terminal"
        }

        let display: Bool?
        switch values["display"] {
        case "1", "true", "yes":
            display = true
        case "0", "false", "no":
            display = false
        default:
            display = nil
        }

        return TerminalCommand(
            name: name.lowercased(),
            minutes: values["minutes"].flatMap(Int.init),
            reason: reason,
            display: display
        )
    }
}
