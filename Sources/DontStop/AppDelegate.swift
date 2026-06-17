import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private lazy var lookAwayReminderController = LookAwayReminderController(settings: settings)
    private let awakeController = AwakeController()
    private let lidAssistController = LidAssistController()
    private let stateStore = StateStore()
    private let commandInbox = CommandInbox()
    private var statusItem: NSStatusItem?
    private var menuRefreshTimer: Timer?
    private var sleepObserver: NSObjectProtocol?
    private var welcomeWindowController: WelcomeWindowController?
    private var transientStatusMenu: NSMenu?
    private var suppressStatusOpenUntil: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !terminateIfAnotherInstanceIsRunning() else {
            return
        }

        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = AppIconFactory.icon(size: 512)

        awakeController.onChange = { [weak self] in
            guard let self else { return }
            self.stateStore.write(controller: self.awakeController)
            self.rebuildMenu()
            self.welcomeWindowController?.refresh(awakeActive: self.awakeController.isActive)
        }

        commandInbox.onCommand = { [weak self] command in
            self?.apply(command: command)
        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.toolTip = "Don't Stop is ready"
            button.setAccessibilityLabel("Don't Stop")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }

        installSleepObserver()
        lidAssistController.reconcileOnLaunch()

        stateStore.write(controller: awakeController)

        rebuildMenu()
        commandInbox.start()
        lookAwayReminderController.start()

        menuRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.rebuildMenu()
        }

        if settings.showWelcomeOnLaunch {
            showWelcomeWindow()
        }
    }

    private func terminateIfAnotherInstanceIsRunning() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let existingApps = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID && !$0.isTerminated }

        guard let existingApp = existingApps.first else {
            return false
        }

        existingApp.activate(options: [])
        NSApp.terminate(nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)
        }
        lookAwayReminderController.stop()
        awakeController.deactivate()
        lidAssistController.restoreWithoutPrompt()
        stateStore.write(controller: awakeController)
    }

    @objc private func toggleHigh() {
        if awakeController.isActive {
            awakeController.deactivate()
        } else {
            awakeController.activate(minutes: settings.defaultDurationMinutes, reason: "Menu")
        }
    }

    @objc private func startForOneHour() {
        awakeController.activate(minutes: 60, reason: "Menu")
    }

    @objc private func startForFourHours() {
        awakeController.activate(minutes: 240, reason: "Menu")
    }

    @objc private func toggleDisplayAwake() {
        awakeController.setDisplayAwake(!awakeController.keepDisplayAwake)
    }

    @objc private func toggleLidAssist() {
        setLidAssist(!lidAssistController.isEnabled, requireConfirmation: true)
    }

    private func setLidAssist(_ enabled: Bool, requireConfirmation: Bool) {
        if enabled == lidAssistController.isEnabled {
            welcomeWindowController?.refresh(awakeActive: awakeController.isActive)
            rebuildMenu()
            return
        }

        if lidAssistController.isEnabled {
            if !lidAssistController.restoreWithAdminPrompt() {
                showLidAssistError()
            }
            welcomeWindowController?.refresh(awakeActive: awakeController.isActive)
            rebuildMenu()
            return
        }

        let needsSafetyConfirmation = requireConfirmation
            && !settings.lidAssistWarningAccepted
            && !lidAssistController.isPasswordlessEnabled
        if needsSafetyConfirmation {
            guard confirmLidAssist() else {
                welcomeWindowController?.refresh(awakeActive: awakeController.isActive)
                return
            }
        }

        if lidAssistController.enableWithAdminPrompt() {
            settings.lidAssistWarningAccepted = true
            if !awakeController.isActive {
                awakeController.activate(minutes: settings.defaultDurationMinutes, reason: "Lid-Closed Running")
            }
        } else {
            showLidAssistError()
        }

        welcomeWindowController?.refresh(awakeActive: awakeController.isActive)
        rebuildMenu()
    }

    @objc private func showWelcomeWindowFromMenu() {
        showWelcomeWindow()
    }

    @objc private func openAgentSetupOnGitHub() {
        NSWorkspace.shared.open(agentSetupURL)
    }

    @objc private func toggleLookAwayReminder() {
        setLookAwayReminder(!settings.lookAwayRemindersEnabled)
    }

    private func setLookAwayReminder(_ enabled: Bool) {
        guard settings.lookAwayRemindersEnabled != enabled else {
            welcomeWindowController?.refresh()
            return
        }

        settings.lookAwayRemindersEnabled = enabled
        lookAwayReminderController.settingsDidChange()
        welcomeWindowController?.refresh()
        rebuildMenu()
    }

    @objc private func showLookAwayBreakNow() {
        settings.lookAwayRemindersEnabled = true
        lookAwayReminderController.showNow()
        welcomeWindowController?.refresh()
        rebuildMenu()
    }

    @objc private func quit() {
        if lidAssistController.isEnabled,
           !lidAssistController.restoreWithAdminPrompt() {
            showLidAssistError()
            return
        }
        NSApp.terminate(nil)
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            return
        }

        if event.type == .rightMouseDown || event.type == .rightMouseUp || event.modifierFlags.contains(.command) {
            showStatusMenu()
            return
        }

        toggleWelcomeWindowFromStatusItem()
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        apply(url: url)
    }

    private func rebuildMenu() {
        guard let button = statusItem?.button else {
            return
        }

        button.image = statusBarIcon(active: awakeController.isActive)
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.attributedTitle = statusBarTitle(text: statusBarText())
        if lidAssistController.isEnabled {
            button.toolTip = "Don't Stop is keeping this Mac awake with lid running"
        } else {
            button.toolTip = awakeController.isActive
                ? "Don't Stop is keeping this Mac awake"
                : "Don't Stop is ready"
        }
    }

    private func statusBarText() -> String {
        if lidAssistController.isEnabled {
            return "Lid"
        }

        return awakeController.isActive ? "Awake" : "Ready"
    }

    private func statusBarIcon(active: Bool) -> NSImage {
        let image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "MacBook") ?? AppIconFactory.menuBarIcon(active: active)
        image.size = NSSize(width: 17, height: 14)
        image.isTemplate = true
        return image
    }

    private func statusBarTitle(text: String) -> NSAttributedString {
        NSAttributedString(
            string: " \(text) ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let statusTitle: String
        if lidAssistController.isEnabled {
            statusTitle = "Status: Keeping Mac Awake, Lid Running"
        } else {
            statusTitle = awakeController.isActive ? "Status: Keeping Mac Awake" : "Status: Ready"
        }
        let status = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if awakeController.isActive {
            let reason = NSMenuItem(title: "Started by: \(awakeController.reason)", action: nil, keyEquivalent: "")
            reason.isEnabled = false
            menu.addItem(reason)

            if let activeUntil = awakeController.activeUntil {
                let remaining = NSMenuItem(title: "Remaining: \(remainingText(until: activeUntil))", action: nil, keyEquivalent: "")
                remaining.isEnabled = false
                menu.addItem(remaining)
            }
        }

        if let lastError = awakeController.lastError {
            let error = NSMenuItem(title: lastError, action: nil, keyEquivalent: "")
            error.isEnabled = false
            menu.addItem(error)
        }

        if let lidError = lidAssistController.lastError {
            let error = NSMenuItem(title: "Lid-Closed Running: \(lidError)", action: nil, keyEquivalent: "")
            error.isEnabled = false
            menu.addItem(error)
        }

        menu.addItem(NSMenuItem.separator())

        let defaultDuration = NSMenuItem(title: "Default Duration: \(DurationOptions.title(for: settings.defaultDurationMinutes))", action: nil, keyEquivalent: "")
        defaultDuration.isEnabled = false
        menu.addItem(defaultDuration)

        let toggle = NSMenuItem(
            title: awakeController.isActive ? "Allow Sleep" : "Keep Mac Awake",
            action: #selector(toggleHigh),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let oneHour = NSMenuItem(title: "Keep Awake for 1 Hour", action: #selector(startForOneHour), keyEquivalent: "")
        oneHour.target = self
        menu.addItem(oneHour)

        let fourHours = NSMenuItem(title: "Keep Awake for 4 Hours", action: #selector(startForFourHours), keyEquivalent: "")
        fourHours.target = self
        menu.addItem(fourHours)

        menu.addItem(NSMenuItem.separator())

        let displayAwake = NSMenuItem(title: "Keep Display Awake", action: #selector(toggleDisplayAwake), keyEquivalent: "")
        displayAwake.target = self
        displayAwake.state = awakeController.keepDisplayAwake ? .on : .off
        menu.addItem(displayAwake)

        let lidAssist = NSMenuItem(
            title: lidAssistController.isEnabled ? "Turn Off Lid-Closed Running..." : "Run With Lid Closed...",
            action: #selector(toggleLidAssist),
            keyEquivalent: ""
        )
        lidAssist.target = self
        lidAssist.state = lidAssistController.isEnabled ? .on : .off
        menu.addItem(lidAssist)

        let lookAway = NSMenuItem(title: "Look-Away Reminder", action: #selector(toggleLookAwayReminder), keyEquivalent: "")
        lookAway.target = self
        lookAway.state = settings.lookAwayRemindersEnabled ? .on : .off
        menu.addItem(lookAway)

        let lookAwayNow = NSMenuItem(title: "Start Look-Away Break Now", action: #selector(showLookAwayBreakNow), keyEquivalent: "")
        lookAwayNow.target = self
        menu.addItem(lookAwayNow)

        menu.addItem(NSMenuItem.separator())

        let welcome = NSMenuItem(title: "Settings...", action: #selector(showWelcomeWindowFromMenu), keyEquivalent: ",")
        welcome.target = self
        menu.addItem(welcome)

        let agentSetup = NSMenuItem(title: "Use With Claude / Codex...", action: #selector(openAgentSetupOnGitHub), keyEquivalent: "")
        agentSetup.target = self
        menu.addItem(agentSetup)

        let quit = NSMenuItem(title: "Quit Don't Stop", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private func apply(command: TerminalCommand) {
        switch command.name {
        case "on", "start", "high", "activate":
            awakeController.activate(minutes: command.minutes, reason: command.reason, display: command.display)
        case "off", "stop", "low", "deactivate":
            awakeController.deactivate()
        case "toggle":
            if awakeController.isActive {
                awakeController.deactivate()
            } else {
                awakeController.activate(minutes: command.minutes, reason: command.reason, display: command.display)
            }
        case "status":
            stateStore.write(controller: awakeController)
        default:
            NSLog("Don't Stop ignored unknown command: \(command.name)")
        }
    }

    private func apply(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }

        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            query[item.name] = item.value ?? ""
        }

        let rawCommand = components.host?.isEmpty == false
            ? components.host!
            : components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let commandName = rawCommand.lowercased()

        if ["settings", "preferences", "panel"].contains(commandName) {
            showWelcomeWindow()
            return
        }

        switch commandName {
        case "display-on", "screen-on":
            awakeController.setDisplayAwake(true)
            rebuildMenu()
            welcomeWindowController?.refresh(awakeActive: awakeController.isActive)
            return
        case "display-off", "screen-off":
            awakeController.setDisplayAwake(false)
            rebuildMenu()
            welcomeWindowController?.refresh(awakeActive: awakeController.isActive)
            return
        case "display-toggle", "screen-toggle":
            awakeController.setDisplayAwake(!awakeController.keepDisplayAwake)
            rebuildMenu()
            welcomeWindowController?.refresh(awakeActive: awakeController.isActive)
            return
        case "lid-on", "lid-enable":
            setLidAssist(true, requireConfirmation: false)
            return
        case "lid-off", "lid-disable":
            setLidAssist(false, requireConfirmation: false)
            return
        case "lid-toggle":
            setLidAssist(!lidAssistController.isEnabled, requireConfirmation: false)
            return
        default:
            break
        }

        let display: Bool?
        switch query["display"]?.lowercased() {
        case "1", "true", "yes":
            display = true
        case "0", "false", "no":
            display = false
        default:
            display = nil
        }

        let command = TerminalCommand(
            name: commandName,
            minutes: query["minutes"].flatMap(Int.init),
            reason: query["reason"] ?? "URL",
            display: display
        )
        apply(command: command)
    }

    private func remainingText(until: Date) -> String {
        let seconds = max(0, Int(until.timeIntervalSinceNow.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(max(1, minutes))m"
    }

    private func showWelcomeWindow() {
        if welcomeWindowController == nil {
            let controller = WelcomeWindowController(settings: settings)
            controller.onToggleAwake = { [weak self] in
                self?.toggleHigh()
            }
            controller.onToggleLidAssist = { [weak self] in
                self?.toggleLidAssist()
            }
            controller.onDisplayPolicyChanged = { [weak self] enabled in
                self?.awakeController.setDisplayAwake(enabled)
            }
            controller.onSettingsChanged = { [weak self] in
                guard let self else { return }
                self.lookAwayReminderController.settingsDidChange()
                self.rebuildMenu()
            }
            controller.onSetLookAway = { [weak self] enabled in
                self?.setLookAwayReminder(enabled)
            }
            controller.onOpenAgentSetup = { [weak self] in
                self?.openAgentSetupOnGitHub()
            }
            controller.onQuit = { [weak self] in
                self?.quit()
            }
            controller.shouldKeepOpenForMouseDown = { [weak self] point in
                self?.statusItemContains(screenPoint: point) ?? false
            }
            controller.isLidAssistEnabledProvider = { [weak self] in
                self?.lidAssistController.isEnabled ?? false
            }
            controller.isDisplayAwakeProvider = { [weak self] in
                self?.awakeController.keepDisplayAwake ?? false
            }
            welcomeWindowController = controller
        }

        welcomeWindowController?.refresh(awakeActive: awakeController.isActive)
        welcomeWindowController?.showWindow(nil)
        positionWelcomeWindowUnderStatusItem()
        welcomeWindowController?.window?.makeKeyAndOrderFront(nil)
        welcomeWindowController?.startAutoDismiss()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func toggleWelcomeWindowFromStatusItem() {
        if welcomeWindowController?.window?.isVisible == true {
            suppressStatusOpenUntil = Date().addingTimeInterval(0.25)
            welcomeWindowController?.close()
            return
        }

        if let suppressStatusOpenUntil,
           Date() < suppressStatusOpenUntil {
            return
        }
        suppressStatusOpenUntil = nil

        showWelcomeWindow()
    }

    private func statusItemContains(screenPoint: NSPoint) -> Bool {
        guard let button = statusItem?.button,
              let window = button.window else {
            return false
        }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = window.convertToScreen(buttonRect).insetBy(dx: -3, dy: -3)
        return screenRect.contains(screenPoint)
    }

    private func positionWelcomeWindowUnderStatusItem() {
        guard let window = welcomeWindowController?.window,
              let button = statusItem?.button,
              let buttonWindow = button.window else {
            welcomeWindowController?.window?.center()
            return
        }

        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectOnScreen = buttonWindow.convertToScreen(buttonRectInWindow)
        let screen = buttonWindow.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = window.frame.size
        let padding: CGFloat = 8

        var originX = buttonRectOnScreen.midX - (size.width / 2)
        originX = max(visibleFrame.minX + padding, min(originX, visibleFrame.maxX - size.width - padding))

        var originY = buttonRectOnScreen.minY - size.height - padding
        if originY < visibleFrame.minY + padding {
            originY = buttonRectOnScreen.maxY + padding
        }

        window.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func showStatusMenu() {
        guard let button = statusItem?.button else {
            return
        }

        transientStatusMenu = makeMenu()
        transientStatusMenu?.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        transientStatusMenu = nil
    }

    private func confirmLidAssist() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Run with the lid closed?"
        alert.informativeText = "Don't Stop will ask for admin permission once, install a scoped rule for the two lid commands, then switch lid mode without asking again. Keep the Mac on a hard surface with airflow."
        alert.addButton(withTitle: "Turn On")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showLidAssistError() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Lid-closed running failed"
        alert.informativeText = lidAssistController.lastError ?? "The pmset command was cancelled or failed."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func installSleepObserver() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.settings.deactivateOnSleep else {
                return
            }
            self.awakeController.deactivate()
        }
    }
}
