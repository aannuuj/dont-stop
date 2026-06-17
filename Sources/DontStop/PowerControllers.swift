import AppKit
import Foundation
import IOKit.pwr_mgt

final class AwakeController {
    private var systemAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0
    private var expirationTimer: Timer?

    private(set) var activeUntil: Date?
    private(set) var keepDisplayAwake = false
    private(set) var lastError: String?
    private(set) var reason = "Manual"

    var onChange: (() -> Void)?

    var isActive: Bool {
        systemAssertion != 0 || displayAssertion != 0
    }

    func activate(minutes: Int? = nil, reason newReason: String = "Manual", display: Bool? = nil) {
        deactivate(notify: false)

        reason = newReason.isEmpty ? "Manual" : newReason
        keepDisplayAwake = display ?? keepDisplayAwake
        lastError = nil

        let assertionName = "Don't Stop: \(reason)" as CFString
        var newSystemAssertion: IOPMAssertionID = 0
        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            assertionName,
            &newSystemAssertion
        )

        if systemResult == kIOReturnSuccess {
            systemAssertion = newSystemAssertion
        } else {
            lastError = "Could not create system sleep assertion (\(systemResult))."
        }

        if keepDisplayAwake {
            var newDisplayAssertion: IOPMAssertionID = 0
            let displayResult = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                assertionName,
                &newDisplayAssertion
            )

            if displayResult == kIOReturnSuccess {
                displayAssertion = newDisplayAssertion
            } else {
                lastError = "Could not create display sleep assertion (\(displayResult))."
            }
        }

        if let minutes, minutes > 0 {
            activeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
            expirationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
                self?.deactivate()
            }
        } else {
            activeUntil = nil
        }

        onChange?()
    }

    func deactivate() {
        deactivate(notify: true)
    }

    func setDisplayAwake(_ enabled: Bool) {
        keepDisplayAwake = enabled
        if isActive {
            activate(minutes: remainingMinutes(), reason: reason, display: enabled)
        } else {
            onChange?()
        }
    }

    private func remainingMinutes() -> Int? {
        guard let activeUntil else { return nil }
        return max(1, Int(ceil(activeUntil.timeIntervalSinceNow / 60.0)))
    }

    private func deactivate(notify: Bool) {
        expirationTimer?.invalidate()
        expirationTimer = nil
        activeUntil = nil

        if systemAssertion != 0 {
            IOPMAssertionRelease(systemAssertion)
            systemAssertion = 0
        }

        if displayAssertion != 0 {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = 0
        }

        if notify {
            onChange?()
        }
    }

    deinit {
        deactivate(notify: false)
    }
}

struct SleepTimerSnapshot {
    let battery: Int?
    let ac: Int?
}

final class LidAssistController {
    private let directory: URL
    private let stateURL: URL
    private let sudoersPath = SudoersAuthorization.sudoersPath

    private(set) var lastError: String?

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: stateURL.path)
    }

    var isPasswordlessEnabled: Bool {
        FileManager.default.fileExists(atPath: sudoersPath)
    }

    init(directory: URL = applicationSupportDirectory()) {
        self.directory = directory
        stateURL = directory.appendingPathComponent("lid-sleep-state", isDirectory: false)
    }

    func enableWithAdminPrompt() -> Bool {
        lastError = nil

        guard ensurePasswordlessWithAdminPrompt() else {
            return false
        }

        guard setDisableSleep(true, allowPrompt: false) else {
            return false
        }

        do {
            try writeDisableSleepStateIfNeeded()
            return true
        } catch {
            lastError = "Closed-lid state was enabled, but Don't Stop could not save its state: \(error.localizedDescription)"
            _ = setDisableSleep(false, allowPrompt: false)
            return false
        }
    }

    func restoreWithAdminPrompt() -> Bool {
        lastError = nil

        let legacySnapshot = readSnapshot()

        if !isPasswordlessEnabled,
           !ensurePasswordlessWithAdminPrompt() {
            return false
        }

        guard setDisableSleep(false, allowPrompt: false) else {
            return false
        }

        if let legacySnapshot,
           (legacySnapshot.battery != nil || legacySnapshot.ac != nil),
           !restoreLegacySleepTimers(legacySnapshot) {
            return false
        }

        try? FileManager.default.removeItem(at: stateURL)
        return true
    }

    func restoreWithoutPrompt() {
        lastError = nil
        if setDisableSleep(false, allowPrompt: false) {
            try? FileManager.default.removeItem(at: stateURL)
        }
    }

    func reconcileOnLaunch() {
        guard isEnabled else {
            return
        }

        restoreWithoutPrompt()
    }

    func enablePasswordlessWithAdminPrompt() -> Bool {
        lastError = nil

        let rule = SudoersAuthorization.sudoersLine(user: NSUserName())
        let command = """
        set -e
        tmp="$(/usr/bin/mktemp /tmp/dont-stop-sudoers.XXXXXX)"
        /usr/bin/printf "%s\\n" \(shellQuoted(rule)) > "$tmp"
        /usr/sbin/visudo -cf "$tmp"
        /usr/sbin/chown root:wheel "$tmp"
        /bin/chmod 0440 "$tmp"
        /bin/mv "$tmp" \(shellQuoted(sudoersPath))
        """

        return runAdminShellCommand(command)
    }

    private func ensurePasswordlessWithAdminPrompt() -> Bool {
        if isPasswordlessEnabled {
            return true
        }

        return enablePasswordlessWithAdminPrompt()
    }

    private func setDisableSleep(_ enabled: Bool, allowPrompt: Bool) -> Bool {
        let value = enabled ? "1" : "0"
        let noPrompt = runProcess(DontStopPowerPolicy.sudoPath, arguments: ["-n", DontStopPowerPolicy.pmsetPath, "-a", "disablesleep", value])
        if noPrompt.status == 0 {
            return true
        }

        guard allowPrompt else {
            lastError = noPrompt.output.isEmpty ? "Passwordless pmset access is not installed." : noPrompt.output
            return false
        }

        return runAdminShellCommand("\(DontStopPowerPolicy.pmsetPath) -a disablesleep \(value)")
    }

    private func writeDisableSleepStateIfNeeded() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let text = [
            "mode=\(LidSleepState().mode)",
            "enabledAt=\(ISO8601DateFormatter().string(from: Date()))"
        ].joined(separator: "\n") + "\n"
        if !FileManager.default.fileExists(atPath: stateURL.path) {
            try text.write(to: stateURL, atomically: true, encoding: .utf8)
        }
    }

    private func restoreLegacySleepTimers(_ snapshot: SleepTimerSnapshot) -> Bool {
        var commands: [String] = []
        if let battery = snapshot.battery {
            commands.append("\(DontStopPowerPolicy.pmsetPath) -b sleep \(battery)")
        }
        if let ac = snapshot.ac {
            commands.append("\(DontStopPowerPolicy.pmsetPath) -c sleep \(ac)")
        }

        guard !commands.isEmpty else {
            lastError = "The saved sleep timer snapshot is empty."
            return false
        }

        return runAdminShellCommand(commands.joined(separator: "; "))
    }

    private func readSnapshot() -> SleepTimerSnapshot? {
        guard let text = try? String(contentsOf: stateURL, encoding: .utf8) else {
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

        return SleepTimerSnapshot(
            battery: values["battery"].flatMap(Int.init),
            ac: values["ac"].flatMap(Int.init)
        )
    }

    private func runAdminShellCommand(_ command: String) -> Bool {
        let script = "do shell script \(appleScriptLiteral(command)) with administrator privileges"
        let result = runProcess("/usr/bin/osascript", arguments: ["-e", script])
        if result.status == 0 {
            return true
        }

        lastError = result.output.isEmpty ? "The admin command was cancelled or failed." : result.output
        return false
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func runProcess(_ launchPath: String, arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (1, error.localizedDescription)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData + errorData, encoding: .utf8) ?? ""
        return (process.terminationStatus, output.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
