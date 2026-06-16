import AppKit
import IOKit.pwr_mgt

final class AwakeController {
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private(set) var isActive = false
    private(set) var keepsDisplayAwake = false

    func start(reason: String = "Don't Stop is keeping the Mac awake") -> Bool {
        guard !isActive else {
            return true
        }

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &systemAssertionID
        )

        isActive = result == kIOReturnSuccess
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
            return
        }

        releaseDisplayAssertion()
        IOPMAssertionRelease(systemAssertionID)
        systemAssertionID = 0
        isActive = false
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        menu.addItem(titleItem)
        menu.addItem(.separator())

        toggleItem.target = self
        menu.addItem(toggleItem)

        displayItem.target = self
        menu.addItem(displayItem)

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
            _ = awakeController.start()
        }

        updateMenu()
    }

    @objc private func toggleDisplayAwake() {
        let nextValue = !awakeController.keepsDisplayAwake

        if !awakeController.isActive {
            _ = awakeController.start()
        }

        _ = awakeController.setDisplayAwake(nextValue)
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

        if let button = statusItem?.button {
            button.title = awakeController.keepsDisplayAwake ? "Display" : (active ? "Awake" : "Ready")
            button.toolTip = active ? "Don't Stop is keeping the Mac awake" : "Don't Stop is ready"
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
