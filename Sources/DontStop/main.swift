import AppKit
import IOKit.pwr_mgt

private let appSupportName = "DontStop"

private func applicationSupportDirectory() -> URL {
    let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return baseURL.appendingPathComponent(appSupportName, isDirectory: true)
}

struct DurationOption {
    let title: String
    let seconds: TimeInterval?

    static let all: [DurationOption] = [
        DurationOption(title: "Until Stopped", seconds: nil),
        DurationOption(title: "30 Minutes", seconds: 30 * 60),
        DurationOption(title: "1 Hour", seconds: 60 * 60),
        DurationOption(title: "4 Hours", seconds: 4 * 60 * 60)
    ]
}

struct TerminalCommand {
    let action: String
    let minutes: Int?
    let display: Bool
    let reason: String
}

final class AwakeController {
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private(set) var isActive = false
    private(set) var keepsDisplayAwake = false
    private(set) var activeUntil: Date?
    var onExpire: (() -> Void)?

    private var expirationTimer: Timer?

    func start(duration: TimeInterval?, reason: String = "Don't Stop is keeping the Mac awake") -> Bool {
        if isActive {
            scheduleExpiration(duration: duration)
            return true
        }

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &systemAssertionID
        )

        isActive = result == kIOReturnSuccess
        if isActive {
            scheduleExpiration(duration: duration)
        }

        return isActive
    }

    func setDisplayAwake(_ enabled: Bool) -> Bool {
        guard isActive else {
            keepsDisplayAwake = false
            return false
        }

        if enabled {
            guard !keepsDisplayAwake else {
                return true
            }

            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Don't Stop is keeping the display awake" as CFString,
                &displayAssertionID
            )

            keepsDisplayAwake = result == kIOReturnSuccess
            return keepsDisplayAwake
        }

        releaseDisplayAssertion()
        return true
    }

    func stop() {
        guard isActive else {
            expirationTimer?.invalidate()
            expirationTimer = nil
            activeUntil = nil
            return
        }

        expirationTimer?.invalidate()
        expirationTimer = nil
        activeUntil = nil

        releaseDisplayAssertion()
        IOPMAssertionRelease(systemAssertionID)
        systemAssertionID = 0
        isActive = false
    }

    func remainingText(now: Date = Date()) -> String {
        guard let activeUntil else {
            return "until stopped"
        }

        let remaining = max(0, Int(activeUntil.timeIntervalSince(now).rounded(.up)))
        let minutes = max(1, Int(ceil(Double(remaining) / 60.0)))
        if minutes < 60 {
            return "\(minutes)m left"
        }

        let hours = minutes / 60
        let leftoverMinutes = minutes % 60
        if leftoverMinutes == 0 {
            return "\(hours)h left"
        }
        return "\(hours)h \(leftoverMinutes)m left"
    }

    private func scheduleExpiration(duration: TimeInterval?) {
        expirationTimer?.invalidate()
        expirationTimer = nil

        guard let duration else {
            activeUntil = nil
            return
        }

        let activeUntil = Date().addingTimeInterval(duration)
        self.activeUntil = activeUntil
        expirationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.stop()
            self?.onExpire?()
        }
    }

    private func releaseDisplayAssertion() {
        guard keepsDisplayAwake else {
            return
        }

        IOPMAssertionRelease(displayAssertionID)
        displayAssertionID = 0
        keepsDisplayAwake = false
    }
}

final class StateStore {
    private let directory = applicationSupportDirectory()
    private lazy var stateURL = directory.appendingPathComponent("state")

    func write(active: Bool, display: Bool, lid: Bool, remaining: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let body = [
                "active=\(active ? "1" : "0")",
                "display=\(display ? "1" : "0")",
                "lid=\(lid ? "1" : "0")",
                "remaining=\(remaining)",
                "updated=\(Int(Date().timeIntervalSince1970))"
            ].joined(separator: "\n") + "\n"

            try body.write(to: stateURL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("Don't Stop could not write state: \(error.localizedDescription)")
        }
    }
}

final class CommandInbox {
    private let directory = applicationSupportDirectory().appendingPathComponent("commands", isDirectory: true)
    private var timer: Timer?

    func start(handler: @escaping (TerminalCommand) -> Void) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("Don't Stop could not create command inbox: \(error.localizedDescription)")
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.processPendingCommands(handler: handler)
        }
        timer?.tolerance = 0.2
    }

    private func processPendingCommands(handler: (TerminalCommand) -> Void) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) else {
            return
        }

        for file in files {
            guard let command = parseCommand(at: file) else {
                try? FileManager.default.removeItem(at: file)
                continue
            }

            handler(command)
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func parseCommand(at file: URL) -> TerminalCommand? {
        guard let body = try? String(contentsOf: file, encoding: .utf8) else {
            return nil
        }

        var values: [String: String] = [:]
        for line in body.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else {
                continue
            }
            values[parts[0]] = parts[1]
        }

        guard let action = values["action"] else {
            return nil
        }

        return TerminalCommand(
            action: action,
            minutes: values["minutes"].flatMap(Int.init),
            display: values["display"] == "1",
            reason: values["reason"] ?? "Terminal"
        )
    }
}

final class LidModeController {
    private(set) var isEnabled = false
    private(set) var lastError: String?

    func setEnabled(_ enabled: Bool) -> Bool {
        lastError = nil

        let value = enabled ? "1" : "0"
        let script = "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            lastError = error.localizedDescription
            return false
        }

        guard process.terminationStatus == 0 else {
            lastError = "macOS did not allow the lid mode change."
            return false
        }

        isEnabled = enabled
        return true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let awakeController = AwakeController()
    private let stateStore = StateStore()
    private let commandInbox = CommandInbox()
    private let lidModeController = LidModeController()
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private let titleItem = NSMenuItem(title: "Don't Stop", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "Keep Mac Awake", action: #selector(toggleAwake), keyEquivalent: "")
    private let displayItem = NSMenuItem(title: "Keep Display Awake", action: #selector(toggleDisplayAwake), keyEquivalent: "")
    private let lidItem = NSMenuItem(title: "Run With Lid Closed", action: #selector(toggleLidMode), keyEquivalent: "")
    private let durationMenu = NSMenu()
    private let durationRootItem = NSMenuItem(title: "Auto Stop", action: nil, keyEquivalent: "")
    private var selectedDurationIndex = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        awakeController.onExpire = { [weak self] in
            self?.updateMenu()
        }

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        menu.addItem(titleItem)
        menu.addItem(.separator())

        toggleItem.target = self
        menu.addItem(toggleItem)

        displayItem.target = self
        menu.addItem(displayItem)

        lidItem.target = self
        menu.addItem(lidItem)

        configureDurationMenu()
        menu.addItem(durationRootItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Don't Stop", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        commandInbox.start { [weak self] command in
            self?.apply(command: command)
        }
        updateMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if lidModeController.isEnabled {
            _ = lidModeController.setEnabled(false)
        }
    }

    @objc private func toggleAwake() {
        if awakeController.isActive {
            awakeController.stop()
        } else {
            _ = awakeController.start(duration: selectedDuration.seconds)
        }

        updateMenu()
    }

    @objc private func toggleDisplayAwake() {
        let nextValue = !awakeController.keepsDisplayAwake

        if !awakeController.isActive {
            _ = awakeController.start(duration: selectedDuration.seconds)
        }

        _ = awakeController.setDisplayAwake(nextValue)
        updateMenu()
    }

    @objc private func durationSelected(_ sender: NSMenuItem) {
        selectedDurationIndex = sender.tag
        if awakeController.isActive {
            _ = awakeController.start(duration: selectedDuration.seconds)
        }
        updateMenu()
    }

    @objc private func toggleLidMode() {
        let shouldEnable = !lidModeController.isEnabled

        if shouldEnable && !confirmLidMode() {
            return
        }

        if shouldEnable && !awakeController.isActive {
            _ = awakeController.start(duration: selectedDuration.seconds)
        }

        if !lidModeController.setEnabled(shouldEnable) {
            showLidModeError()
        }

        updateMenu()
    }

    @objc private func quit() {
        if lidModeController.isEnabled {
            _ = lidModeController.setEnabled(false)
        }
        awakeController.stop()
        NSApp.terminate(nil)
    }

    private func updateMenu() {
        let active = awakeController.isActive
        titleItem.title = active ? "Don't Stop: Awake" : "Don't Stop: Ready"
        toggleItem.title = active ? "Stop Keeping Awake" : "Keep Mac Awake"
        toggleItem.state = active ? .on : .off
        displayItem.isEnabled = active
        displayItem.state = awakeController.keepsDisplayAwake ? .on : .off
        lidItem.state = lidModeController.isEnabled ? .on : .off
        durationRootItem.title = active ? "Auto Stop: \(awakeController.remainingText())" : "Auto Stop"

        for item in durationMenu.items {
            item.state = item.tag == selectedDurationIndex ? .on : .off
        }

        if let button = statusItem?.button {
            button.title = lidModeController.isEnabled ? "Lid" : (awakeController.keepsDisplayAwake ? "Display" : (active ? "Awake" : "Ready"))
            button.toolTip = active ? "Don't Stop is keeping the Mac awake" : "Don't Stop is ready"
        }

        stateStore.write(
            active: active,
            display: awakeController.keepsDisplayAwake,
            lid: lidModeController.isEnabled,
            remaining: awakeController.remainingText()
        )
    }

    private var selectedDuration: DurationOption {
        DurationOption.all[selectedDurationIndex]
    }

    private func configureDurationMenu() {
        for (index, option) in DurationOption.all.enumerated() {
            let item = NSMenuItem(title: option.title, action: #selector(durationSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            durationMenu.addItem(item)
        }

        durationRootItem.submenu = durationMenu
    }

    private func confirmLidMode() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Run with the lid closed?"
        alert.informativeText = "This is opt-in because closed-lid running can increase heat. Use a hard surface with airflow, preferably on power, and turn it off when the run is done."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Turn On")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showLidModeError() {
        let alert = NSAlert()
        alert.messageText = "Lid mode could not be changed"
        alert.informativeText = lidModeController.lastError ?? "macOS did not allow the system power setting change."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func apply(command: TerminalCommand) {
        switch command.action {
        case "on":
            let duration = command.minutes.map { TimeInterval($0 * 60) }
            _ = awakeController.start(duration: duration, reason: command.reason)
            if command.display {
                _ = awakeController.setDisplayAwake(true)
            }
        case "off":
            if lidModeController.isEnabled {
                _ = lidModeController.setEnabled(false)
            }
            awakeController.stop()
        default:
            break
        }

        updateMenu()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
