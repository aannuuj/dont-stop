import AppKit
import IOKit.pwr_mgt

final class AwakeController {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false

    func start(reason: String = "Don't Stop is keeping the Mac awake") -> Bool {
        guard !isActive else {
            return true
        }

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )

        isActive = result == kIOReturnSuccess
        return isActive
    }

    func stop() {
        guard isActive else {
            return
        }

        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let awakeController = AwakeController()
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private let titleItem = NSMenuItem(title: "Don't Stop", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "Keep Mac Awake", action: #selector(toggleAwake), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        menu.addItem(titleItem)
        menu.addItem(.separator())

        toggleItem.target = self
        menu.addItem(toggleItem)

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

    @objc private func quit() {
        awakeController.stop()
        NSApp.terminate(nil)
    }

    private func updateMenu() {
        let active = awakeController.isActive
        titleItem.title = active ? "Don't Stop: Awake" : "Don't Stop: Ready"
        toggleItem.title = active ? "Stop Keeping Awake" : "Keep Mac Awake"
        toggleItem.state = active ? .on : .off

        if let button = statusItem?.button {
            button.title = active ? "Awake" : "Ready"
            button.toolTip = active ? "Don't Stop is keeping the Mac awake" : "Don't Stop is ready"
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
