import AppKit
import SwiftUI

final class WelcomeWindowController: NSWindowController {
    private let settings: AppSettings
    private let durationPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let displayPolicyControl = NativeSegmentedControl(labels: ["Sleep", "Stay on"])
    private let awakeSwitch = NativeSwitchControl()
    private let lidSwitch = NativeSwitchControl()
    private let lookAwayControl = NativeSegmentedControl(labels: ["Off", "On"])
    private var isAwakeActive = false
    private var localDismissMonitor: Any?
    private var globalDismissMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?

    var onToggleAwake: (() -> Void)?
    var onToggleLidAssist: (() -> Void)?
    var onDisplayPolicyChanged: ((Bool) -> Void)?
    var onSettingsChanged: (() -> Void)?
    var isLidAssistEnabledProvider: (() -> Bool)?
    var isDisplayAwakeProvider: (() -> Bool)?
    var onSetLookAway: ((Bool) -> Void)?
    var onOpenAgentSetup: (() -> Void)?
    var onQuit: (() -> Void)?
    var shouldKeepOpenForMouseDown: ((NSPoint) -> Bool)?

    init(settings: AppSettings) {
        self.settings = settings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 306, height: 376),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "Don't Stop"
        window.appearance = nil
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .transient]

        super.init(window: window)
        buildContent()
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopAutoDismiss()
    }

    override func close() {
        stopAutoDismiss()
        super.close()
    }

    func startAutoDismiss() {
        stopAutoDismiss()

        localDismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else {
                return event
            }

            if let point = self.screenPoint(for: event),
               self.shouldKeepOpenForMouseDown?(point) == true {
                return event
            }

            if self.shouldDismiss(for: event) {
                self.close()
            }

            return event
        }

        globalDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                if self.shouldKeepOpenForMouseDown?(NSEvent.mouseLocation) == true {
                    return
                }

                self.close()
            }
        }

        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }

            if self.shouldKeepOpenForMouseDown?(NSEvent.mouseLocation) == true {
                return
            }

            self.close()
        }
    }

    private func stopAutoDismiss() {
        if let localDismissMonitor {
            NSEvent.removeMonitor(localDismissMonitor)
            self.localDismissMonitor = nil
        }

        if let globalDismissMonitor {
            NSEvent.removeMonitor(globalDismissMonitor)
            self.globalDismissMonitor = nil
        }

        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
            self.resignActiveObserver = nil
        }
    }

    private func shouldDismiss(for event: NSEvent) -> Bool {
        guard let window, window.isVisible else {
            return false
        }

        guard let eventWindow = event.window else {
            return true
        }

        if eventWindow === window {
            return false
        }

        if eventWindow.level == .popUpMenu {
            return false
        }

        return true
    }

    private func screenPoint(for event: NSEvent) -> NSPoint? {
        guard let eventWindow = event.window else {
            return nil
        }

        let rect = NSRect(origin: event.locationInWindow, size: .zero)
        return eventWindow.convertToScreen(rect).origin
    }

    func refresh(awakeActive: Bool? = nil) {
        if let awakeActive {
            isAwakeActive = awakeActive
        }

        let selected = DurationOptions.option(forStoredValue: settings.defaultDurationMinutes ?? 0)
        durationPopUp.selectItem(withTitle: selected.title)
        displayPolicyControl.selectedSegment = (isDisplayAwakeProvider?() ?? false) ? 1 : 0
        awakeSwitch.state = isAwakeActive ? .on : .off
        lidSwitch.state = (isLidAssistEnabledProvider?() ?? false) ? .on : .off
        lookAwayControl.selectedSegment = settings.lookAwayRemindersEnabled ? 1 : 0
    }

    @objc private func durationChanged() {
        let index = durationPopUp.indexOfSelectedItem
        guard DurationOptions.all.indices.contains(index) else {
            return
        }
        settings.defaultDurationMinutes = DurationOptions.all[index].minutes
        onSettingsChanged?()
    }

    @objc private func displayPolicyChanged() {
        onDisplayPolicyChanged?(displayPolicyControl.selectedSegment == 1)
        refresh()
    }

    @objc private func awakeSwitchChanged() {
        onToggleAwake?()
        refresh()
    }

    @objc private func lidSwitchChanged() {
        onToggleLidAssist?()
        refresh()
    }

    @objc private func lookAwayControlChanged() {
        let enabled = lookAwayControl.selectedSegment == 1
        guard settings.lookAwayRemindersEnabled != enabled else {
            return
        }

        onSetLookAway?(enabled)
        refresh()
    }

    @objc private func quitPressed() {
        onQuit?()
    }

    @objc private func agentSetupPressed() {
        onOpenAgentSetup?()
    }

    private func buildContent() {
        guard let window else {
            return
        }

        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        let content = GlassPanelView()
        content.material = .popover
        content.blendingMode = .behindWindow
        content.state = .active
        content.wantsLayer = true
        content.layer?.cornerRadius = 22
        if #available(macOS 10.15, *) {
            content.layer?.cornerCurve = .continuous
        }
        content.layer?.masksToBounds = true
        content.onAppearanceChange = { [weak self, weak content] in
            guard let self, let content else { return }
            self.applyContentAppearance(to: content)
        }
        applyContentAppearance(to: content)
        window.contentView = content

        durationPopUp.addItems(withTitles: DurationOptions.all.map(\.title))
        configurePopUp(durationPopUp, action: #selector(durationChanged))

        configureSegmentedControl(displayPolicyControl, action: #selector(displayPolicyChanged))

        configureSwitch(awakeSwitch, action: #selector(awakeSwitchChanged))
        configureSwitch(lidSwitch, action: #selector(lidSwitchChanged))

        let awakeGroup = makeGroup([
            makeSettingRow(
                title: "Stay awake",
                subtitle: "Block idle sleep",
                control: awakeSwitch
            ),
            makeThinDivider(),
            makePickerRow(title: "Display", control: displayPolicyControl),
            makePickerRow(title: "Timer", control: durationPopUp)
        ])

        let lidGroup = makeGroup([
            makeSettingRow(
                title: "Lid mode",
                subtitle: "Keep jobs running closed",
                control: lidSwitch
            ),
            makeRiskRow(),
            makeCaveatRow()
        ])

        let agentSetupNudge = makeAgentSetupNudge()
        let footerButtons = makeFooterButtons()

        let controlsStack = NSStackView(views: [awakeGroup, lidGroup, agentSetupNudge, footerButtons])
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.orientation = .vertical
        controlsStack.alignment = .width
        controlsStack.distribution = .fill
        controlsStack.spacing = 10

        content.addSubview(controlsStack)

        for view in controlsStack.arrangedSubviews {
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: controlsStack.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: controlsStack.trailingAnchor)
            ])
        }

        NSLayoutConstraint.activate([
            controlsStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            controlsStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            controlsStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            controlsStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14)
        ])
    }

    private var primaryText: NSColor {
        .labelColor
    }

    private var secondaryText: NSColor {
        .secondaryLabelColor
    }

    private var mutedText: NSColor {
        .tertiaryLabelColor
    }

    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private func applyContentAppearance(to content: NSVisualEffectView) {
        content.material = .popover
        content.layer?.backgroundColor = NSColor.clear.cgColor
        content.layer?.borderWidth = 0
        content.needsDisplay = true
    }

    private func applyGroupAppearance(to panel: AppearanceAwareView) {
        panel.layer?.backgroundColor = adaptiveColor(
            for: panel,
            light: NSColor(calibratedWhite: 1.0, alpha: 0.18),
            dark: NSColor(calibratedWhite: 1.0, alpha: 0.075)
        ).cgColor
        panel.layer?.borderColor = adaptiveColor(
            for: panel,
            light: NSColor(calibratedWhite: 1.0, alpha: 0.32),
            dark: NSColor(calibratedWhite: 1.0, alpha: 0.16)
        ).cgColor
    }

    private func applyAgentNudgeAppearance(to panel: AppearanceAwareView) {
        panel.layer?.backgroundColor = adaptiveColor(
            for: panel,
            light: NSColor(calibratedWhite: 1.0, alpha: 0.18),
            dark: NSColor(calibratedWhite: 1.0, alpha: 0.09)
        ).cgColor
        panel.layer?.borderColor = adaptiveColor(
            for: panel,
            light: NSColor(calibratedWhite: 1.0, alpha: 0.30),
            dark: NSColor(calibratedWhite: 1.0, alpha: 0.15)
        ).cgColor
    }

    private func makeGroup(_ rows: [NSView]) -> NSView {
        let panel = AppearanceAwareView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.wantsLayer = true
        panel.layer?.borderWidth = 1
        panel.layer?.cornerRadius = 16
        if #available(macOS 10.15, *) {
            panel.layer?.cornerCurve = .continuous
        }
        panel.onAppearanceChange = { [weak self] panel in
            self?.applyGroupAppearance(to: panel)
        }
        applyGroupAppearance(to: panel)

        let stack = NSStackView(views: rows)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 0

        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 11),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -11),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 9),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -9)
        ])

        return panel
    }

    private func makeSettingRow(title: String, subtitle: String?, control: NSView) -> NSView {
        let titleLabel = makeLabel(title, size: 13, weight: .semibold, color: primaryText)
        titleLabel.maximumNumberOfLines = 1

        var textViews: [NSView] = [titleLabel]
        if let subtitle {
            let subtitleLabel = makeLabel(subtitle, size: 10, weight: .medium, color: secondaryText)
            subtitleLabel.preferredMaxLayoutWidth = 230
            textViews.append(subtitleLabel)
        }

        let textStack = NSStackView(views: textViews)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3

        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.required, for: .horizontal)

        row.addSubview(textStack)
        row.addSubview(control)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: subtitle == nil ? 32 : 44),

            textStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 0),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -14),
            textStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: 0),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func makePickerRow(title: String, control: NSView) -> NSView {
        let label = makeLabel(title, size: 13, weight: .semibold, color: primaryText)
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)
        row.addSubview(control)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 32),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            control.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 12),
            control.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            control.widthAnchor.constraint(equalToConstant: 116)
        ])
        return row
    }

    private func makeRiskRow() -> NSView {
        let icon = NSImageView(image: NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Warning") ?? NSImage())
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        icon.contentTintColor = mutedText

        let label = makeLabel(DontStopPowerPolicy.lidHeatWarning, size: 10, weight: .medium, color: mutedText)
        label.maximumNumberOfLines = 1

        let row = NSStackView(views: [icon, label])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 18),
            icon.widthAnchor.constraint(equalToConstant: 11),
            icon.heightAnchor.constraint(equalToConstant: 11)
        ])
        return row
    }

    private func makeCaveatRow() -> NSView {
        let label = makeLabel("Apple Silicon: \(DontStopPowerPolicy.compactLidCaveat)", size: 9.5, weight: .regular, color: mutedText)
        label.maximumNumberOfLines = 1

        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 17),
            label.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    private func makeFooterButtons() -> NSView {
        let lookAwayGroup = makeLookAwayFooterControl()
        let quitButton = makeFooterButton(title: "Quit Don't Stop", action: #selector(quitPressed))

        let row = NSStackView(views: [lookAwayGroup, quitButton])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 8
        quitButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        lookAwayGroup.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 34),
            lookAwayGroup.widthAnchor.constraint(equalToConstant: 144),
            lookAwayGroup.heightAnchor.constraint(equalToConstant: 34),
            quitButton.heightAnchor.constraint(equalToConstant: 34)
        ])

        return row
    }

    private func makeAgentSetupNudge() -> NSView {
        let row = AppearanceAwareView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.wantsLayer = true
        row.layer?.borderWidth = 1
        row.layer?.cornerRadius = 12
        if #available(macOS 10.15, *) {
            row.layer?.cornerCurve = .continuous
        }
        row.onAppearanceChange = { [weak self] row in
            self?.applyAgentNudgeAppearance(to: row)
        }
        applyAgentNudgeAppearance(to: row)

        let button = NSButton(title: "", target: self, action: #selector(agentSetupPressed))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.toolTip = "Open GitHub setup for agent coding editors and CLI wrapping"
        button.setAccessibilityLabel("Use with Codex or Claude on GitHub")

        let title = makeLabel("Use with Codex / Claude", size: 11.5, weight: .semibold, color: primaryText)
        title.maximumNumberOfLines = 1

        let subtitle = makeLabel("Open GitHub setup for agentic coding editors", size: 9.5, weight: .medium, color: secondaryText)
        subtitle.maximumNumberOfLines = 1

        let textStack = NSStackView(views: [title, subtitle])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let arrow = NSImageView(image: NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: nil) ?? NSImage())
        arrow.translatesAutoresizingMaskIntoConstraints = false
        arrow.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        arrow.contentTintColor = secondaryText

        row.addSubview(button)
        row.addSubview(textStack)
        row.addSubview(arrow)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 52),

            button.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            button.topAnchor.constraint(equalTo: row.topAnchor),
            button.bottomAnchor.constraint(equalTo: row.bottomAnchor),

            textStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 15),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: arrow.leadingAnchor, constant: -10),
            textStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            arrow.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            arrow.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 12),
            arrow.heightAnchor.constraint(equalToConstant: 12)
        ])

        return row
    }

    private func makeFooterButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        configureFooterButton(button, title: title, action: action)
        return button
    }

    private func configureFooterButton(_ button: NSButton, title: String, action: Selector) {
        button.title = title
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        button.target = self
        button.action = action
        button.setContentHuggingPriority(.required, for: .vertical)
    }

    private func makeLookAwayFooterControl() -> NSView {
        configureLookAwayControl()

        let label = makeLabel("Look-Away", size: 10.5, weight: .semibold, color: secondaryText)
        label.maximumNumberOfLines = 1

        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)
        row.addSubview(lookAwayControl)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 34),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            lookAwayControl.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
            lookAwayControl.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            lookAwayControl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            lookAwayControl.widthAnchor.constraint(equalToConstant: 78),
            lookAwayControl.heightAnchor.constraint(equalToConstant: 28)
        ])

        return row
    }

    private func configureLookAwayControl() {
        lookAwayControl.translatesAutoresizingMaskIntoConstraints = false
        lookAwayControl.target = self
        lookAwayControl.action = #selector(lookAwayControlChanged)
        lookAwayControl.controlSize = .regular
        lookAwayControl.tint = .accentColor
        lookAwayControl.toolTip = "Look-Away Reminder"
        lookAwayControl.setAccessibilityLabel("Look-Away Reminder")
    }

    private func makeDivider() -> NSView {
        let line = AppearanceAwareView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.wantsLayer = true
        line.onAppearanceChange = { line in
            line.layer?.backgroundColor = adaptiveColor(
                for: line,
                light: NSColor(calibratedWhite: 0.35, alpha: 0.16),
                dark: NSColor(calibratedWhite: 1.0, alpha: 0.12)
            ).cgColor
        }
        line.onAppearanceChange?(line)
        NSLayoutConstraint.activate([
            line.heightAnchor.constraint(equalToConstant: 1)
        ])
        return line
    }

    private func makeThinDivider() -> NSView {
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        let line = makeDivider()
        wrapper.addSubview(line)
        NSLayoutConstraint.activate([
            wrapper.heightAnchor.constraint(equalToConstant: 7),
            line.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            line.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor)
        ])
        return wrapper
    }

    private func configureSwitch(_ switchControl: NativeSwitchControl, action: Selector) {
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.target = self
        switchControl.action = action
        switchControl.controlSize = .regular
        switchControl.tint = .accentColor
    }

    private func configurePopUp(_ popUp: NSPopUpButton, action: Selector) {
        popUp.translatesAutoresizingMaskIntoConstraints = false
        popUp.target = self
        popUp.action = action
        popUp.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        popUp.controlSize = .regular
        popUp.bezelStyle = .rounded
        popUp.isBordered = true
    }

    private func configureSegmentedControl(_ control: NativeSegmentedControl, action: Selector) {
        control.translatesAutoresizingMaskIntoConstraints = false
        control.target = self
        control.action = action
        control.controlSize = .regular
        control.tint = .accentColor
    }
}
