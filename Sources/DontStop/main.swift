import AppKit
import IOKit.pwr_mgt

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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let awakeController = AwakeController()
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private let titleItem = NSMenuItem(title: "Don't Stop", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "Keep Mac Awake", action: #selector(toggleAwake), keyEquivalent: "")
    private let displayItem = NSMenuItem(title: "Keep Display Awake", action: #selector(toggleDisplayAwake), keyEquivalent: "")
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

        configureDurationMenu()
        menu.addItem(durationRootItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Don't Stop", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        updateMenu()
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

    @objc private func quit() {
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
        durationRootItem.title = active ? "Auto Stop: \(awakeController.remainingText())" : "Auto Stop"

        for item in durationMenu.items {
            item.state = item.tag == selectedDurationIndex ? .on : .off
        }

        if let button = statusItem?.button {
            button.title = awakeController.keepsDisplayAwake ? "Display" : (active ? "Awake" : "Ready")
            button.toolTip = active ? "Don't Stop is keeping the Mac awake" : "Don't Stop is ready"
        }
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
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
