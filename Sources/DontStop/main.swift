import AppKit
import Foundation
import IOKit.pwr_mgt
import SwiftUI

private let appSupportName = "DontStop"
private let agentSetupURL = URL(string: "https://github.com/aannuuj/dont-stop/blob/main/docs/agent-setup.md")!

private enum MonoPalette {
    static let canvasTop = NSColor(calibratedWhite: 0.060, alpha: 1.0)
    static let canvasBottom = NSColor(calibratedWhite: 0.030, alpha: 1.0)
    static let surface = NSColor(calibratedWhite: 1.0, alpha: 0.075)
    static let surfaceRaised = NSColor(calibratedWhite: 1.0, alpha: 0.115)
    static let surfacePressed = NSColor(calibratedWhite: 1.0, alpha: 0.155)
    static let line = NSColor(calibratedWhite: 1.0, alpha: 0.165)
    static let lineStrong = NSColor(calibratedWhite: 1.0, alpha: 0.28)
    static let text = NSColor(calibratedWhite: 0.97, alpha: 1.0)
    static let textSecondary = NSColor(calibratedWhite: 0.74, alpha: 1.0)
    static let textMuted = NSColor(calibratedWhite: 0.56, alpha: 1.0)
    static let control = NSColor(calibratedWhite: 1.0, alpha: 0.14)
    static let controlStrong = NSColor(calibratedWhite: 1.0, alpha: 0.21)
}

private func applicationSupportDirectory() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support", isDirectory: true)
        .appendingPathComponent(appSupportName, isDirectory: true)
}

private struct DurationOption {
    let title: String
    let minutes: Int?

    var storedValue: Int {
        minutes ?? 0
    }
}

private enum DurationOptions {
    static let all: [DurationOption] = [
        DurationOption(title: "Until stopped", minutes: nil),
        DurationOption(title: "5 min", minutes: 5),
        DurationOption(title: "15 min", minutes: 15),
        DurationOption(title: "30 min", minutes: 30),
        DurationOption(title: "1 hr", minutes: 60),
        DurationOption(title: "2 hr", minutes: 120),
        DurationOption(title: "4 hr", minutes: 240),
        DurationOption(title: "8 hr", minutes: 480)
    ]

    static func option(forStoredValue storedValue: Int) -> DurationOption {
        all.first { $0.storedValue == storedValue } ?? all[0]
    }

    static func title(for minutes: Int?) -> String {
        all.first { $0.minutes == minutes }?.title ?? "\(minutes ?? 0) minutes"
    }
}

private final class AppSettings {
    private enum Key {
        static let defaultDurationMinutes = "defaultDurationMinutes"
        static let deactivateOnSleep = "deactivateOnSleep"
        static let showWelcomeOnLaunch = "showWelcomeOnLaunch"
        static let lidAssistWarningAccepted = "lidAssistWarningAccepted"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.defaultDurationMinutes: 0,
            Key.deactivateOnSleep: true,
            Key.showWelcomeOnLaunch: false,
            Key.lidAssistWarningAccepted: false
        ])
    }

    var defaultDurationMinutes: Int? {
        get {
            let rawValue = defaults.integer(forKey: Key.defaultDurationMinutes)
            return rawValue > 0 ? rawValue : nil
        }
        set {
            defaults.set(newValue ?? 0, forKey: Key.defaultDurationMinutes)
        }
    }

    var deactivateOnSleep: Bool {
        get { defaults.bool(forKey: Key.deactivateOnSleep) }
        set { defaults.set(newValue, forKey: Key.deactivateOnSleep) }
    }

    var showWelcomeOnLaunch: Bool {
        get { defaults.bool(forKey: Key.showWelcomeOnLaunch) }
        set { defaults.set(newValue, forKey: Key.showWelcomeOnLaunch) }
    }


    var lidAssistWarningAccepted: Bool {
        get { defaults.bool(forKey: Key.lidAssistWarningAccepted) }
        set { defaults.set(newValue, forKey: Key.lidAssistWarningAccepted) }
    }
}

private enum AppIconFactory {
    static func menuBarIcon(active: Bool) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let bounds = NSRect(x: 1, y: 1, width: size - 2, height: size - 2)
        let circle = NSBezierPath(ovalIn: bounds)

        if active {
            MonoPalette.text.setFill()
            circle.fill()
        } else {
            MonoPalette.textMuted.setStroke()
            circle.lineWidth = 2
            circle.stroke()
        }

        let pulse = NSBezierPath()
        pulse.move(to: NSPoint(x: 4, y: 9))
        pulse.line(to: NSPoint(x: 6.7, y: 9))
        pulse.line(to: NSPoint(x: 8.4, y: 12.7))
        pulse.line(to: NSPoint(x: 10.9, y: 5.4))
        pulse.line(to: NSPoint(x: 12.7, y: 9))
        pulse.line(to: NSPoint(x: 15, y: 9))
        (active ? NSColor.black.withAlphaComponent(0.86) : MonoPalette.textMuted).setStroke()
        pulse.lineWidth = 2.0
        pulse.lineCapStyle = .round
        pulse.lineJoinStyle = .round
        pulse.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func icon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let bounds = NSRect(x: 0, y: 0, width: size, height: size)
        let outer = NSBezierPath(roundedRect: bounds.insetBy(dx: size * 0.06, dy: size * 0.06), xRadius: size * 0.18, yRadius: size * 0.18)
        NSGradient(colors: [
            NSColor(calibratedWhite: 0.30, alpha: 1.0),
            NSColor(calibratedWhite: 0.10, alpha: 1.0)
        ])?.draw(in: outer, angle: 270)

        MonoPalette.lineStrong.setStroke()
        outer.lineWidth = size * 0.018
        outer.stroke()

        let inner = NSBezierPath(roundedRect: bounds.insetBy(dx: size * 0.24, dy: size * 0.22), xRadius: size * 0.08, yRadius: size * 0.08)
        NSGradient(colors: [
            NSColor(calibratedWhite: 0.94, alpha: 1.0),
            NSColor(calibratedWhite: 0.64, alpha: 1.0)
        ])?.draw(in: inner, angle: 270)

        let pulse = NSBezierPath()
        pulse.move(to: NSPoint(x: size * 0.31, y: size * 0.50))
        pulse.line(to: NSPoint(x: size * 0.41, y: size * 0.50))
        pulse.line(to: NSPoint(x: size * 0.48, y: size * 0.64))
        pulse.line(to: NSPoint(x: size * 0.57, y: size * 0.36))
        pulse.line(to: NSPoint(x: size * 0.65, y: size * 0.50))
        pulse.line(to: NSPoint(x: size * 0.73, y: size * 0.50))
        NSColor.black.withAlphaComponent(0.84).setStroke()
        pulse.lineWidth = max(3, size * 0.045)
        pulse.lineCapStyle = .round
        pulse.lineJoinStyle = .round
        pulse.stroke()

        let text = "DS" as NSString
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let textRect = NSRect(x: size * 0.18, y: size * 0.08, width: size * 0.64, height: size * 0.22)
        text.draw(in: textRect, withAttributes: [
            .font: NSFont.systemFont(ofSize: size * 0.13, weight: .bold),
            .foregroundColor: NSColor.black.withAlphaComponent(0.68),
            .paragraphStyle: paragraph
        ])

        image.unlockFocus()
        return image
    }
}

private final class ArcBackdropView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        NSGradient(colors: [
            MonoPalette.canvasTop,
            MonoPalette.canvasBottom
        ])?.draw(in: bounds, angle: 260)
    }
}

private final class ActionTileControl: NSControl {
    private let materialView = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "")
    private let emphasized: Bool

    init(emphasized: Bool, badge: String) {
        self.emphasized = emphasized
        super.init(frame: .zero)
        setup(badge: badge)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    func setText(title: String, subtitle: String) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
    }

    override func mouseDown(with event: NSEvent) {
        setPressed(true)
    }

    override func mouseUp(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        setPressed(false)
        if inside {
            sendAction(action, to: target)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 {
            sendAction(action, to: target)
            return
        }
        super.keyDown(with: event)
    }

    private func setup(badge: String) {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 10
        layer?.shadowOffset = NSSize(width: 0, height: -4)

        materialView.translatesAutoresizingMaskIntoConstraints = false
        materialView.material = .hudWindow
        materialView.blendingMode = .withinWindow
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.backgroundColor = (emphasized ? MonoPalette.surfaceRaised : MonoPalette.surface).cgColor
        materialView.layer?.borderColor = (emphasized ? MonoPalette.lineStrong : MonoPalette.line).cgColor
        materialView.layer?.borderWidth = 1
        materialView.layer?.cornerRadius = 18

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.stringValue = badge
        badgeLabel.alignment = .center
        badgeLabel.font = NSFont.systemFont(ofSize: 11, weight: .heavy)
        badgeLabel.textColor = emphasized ? MonoPalette.text : MonoPalette.textSecondary
        badgeLabel.wantsLayer = true
        badgeLabel.layer?.backgroundColor = (emphasized ? MonoPalette.controlStrong : MonoPalette.control).cgColor
        badgeLabel.layer?.cornerRadius = 11

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = MonoPalette.text

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = MonoPalette.textSecondary
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.lineBreakMode = .byWordWrapping

        let textStack = NSStackView(views: [badgeLabel, titleLabel, subtitleLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 7

        addSubview(materialView)
        materialView.addSubview(textStack)

        NSLayoutConstraint.activate([
            materialView.leadingAnchor.constraint(equalTo: leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: trailingAnchor),
            materialView.topAnchor.constraint(equalTo: topAnchor),
            materialView.bottomAnchor.constraint(equalTo: bottomAnchor),

            textStack.leadingAnchor.constraint(equalTo: materialView.leadingAnchor, constant: 20),
            textStack.trailingAnchor.constraint(equalTo: materialView.trailingAnchor, constant: -20),
            textStack.centerYAnchor.constraint(equalTo: materialView.centerYAnchor),

            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 58),
            badgeLabel.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    private func setPressed(_ pressed: Bool) {
        alphaValue = pressed ? 0.82 : 1.0
        materialView.layer?.backgroundColor = (pressed ? MonoPalette.surfacePressed : (emphasized ? MonoPalette.surfaceRaised : MonoPalette.surface)).cgColor
    }
}

private func isDarkAppearance(_ appearance: NSAppearance) -> Bool {
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
}

private func adaptiveColor(for view: NSView, light: NSColor, dark: NSColor) -> NSColor {
    isDarkAppearance(view.effectiveAppearance) ? dark : light
}

private class AppearanceAwareVisualEffectView: NSVisualEffectView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onAppearanceChange?()
    }
}

private final class GlassPanelView: AppearanceAwareVisualEffectView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let radius: CGFloat = 22
        let bounds = self.bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        let dark = isDarkAppearance(effectiveAppearance)

        NSGraphicsContext.saveGraphicsState()
        path.addClip()

        let sheenColors: [NSColor] = dark
            ? [
                NSColor.white.withAlphaComponent(0.18),
                NSColor.white.withAlphaComponent(0.05),
                NSColor.black.withAlphaComponent(0.18)
            ]
            : [
                NSColor.white.withAlphaComponent(0.36),
                NSColor.white.withAlphaComponent(0.12),
                NSColor.black.withAlphaComponent(0.04)
            ]
        NSGradient(colors: sheenColors)?.draw(in: bounds, angle: 300)

        let edgeGlow = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: radius - 1.5, yRadius: radius - 1.5)
        (dark ? NSColor.white.withAlphaComponent(0.045) : NSColor.white.withAlphaComponent(0.12)).setStroke()
        edgeGlow.lineWidth = 1
        edgeGlow.stroke()

        NSGraphicsContext.restoreGraphicsState()

        (dark ? NSColor.white.withAlphaComponent(0.24) : NSColor.white.withAlphaComponent(0.58)).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

private final class AppearanceAwareView: NSView {
    var onAppearanceChange: ((AppearanceAwareView) -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?(self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onAppearanceChange?(self)
    }
}

private func swiftUIControlSize(from controlSize: NSControl.ControlSize) -> SwiftUI.ControlSize {
    switch controlSize {
    case .mini:
        return .mini
    case .small:
        return .small
    case .large:
        return .large
    default:
        return .regular
    }
}

private struct NativeSwitchView: View {
    let isOn: Bool
    let isEnabled: Bool
    let tint: Color
    let controlSize: SwiftUI.ControlSize
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(
            "",
            isOn: Binding(
                get: { isOn },
                set: { onChange($0) }
            )
        )
        .labelsHidden()
        .toggleStyle(.switch)
        .tint(tint)
        .controlSize(controlSize)
        .disabled(!isEnabled)
        .frame(width: 52, height: 30)
    }
}

private final class NativeSwitchControl: NSView {
    var state: NSControl.StateValue = .off {
        didSet {
            updateRootView()
        }
    }

    weak var target: AnyObject?
    var action: Selector?
    var tint: Color = .accentColor {
        didSet {
            updateRootView()
        }
    }
    var controlSize: NSControl.ControlSize = .regular {
        didSet {
            updateRootView()
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 52, height: 30)
    }

    var isEnabled: Bool = true {
        didSet {
            updateRootView()
        }
    }

    private var hostingView: NSHostingView<NativeSwitchView>?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        let host = NSHostingView(rootView: makeRootView())
        host.translatesAutoresizingMaskIntoConstraints = false
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(host)
        hostingView = host

        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: 52),
            heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private func makeRootView() -> NativeSwitchView {
        NativeSwitchView(
            isOn: state == .on,
            isEnabled: isEnabled,
            tint: tint,
            controlSize: swiftUIControlSize(from: controlSize)
        ) { [weak self] enabled in
            guard let self else {
                return
            }

            state = enabled ? .on : .off
            if let action {
                NSApp.sendAction(action, to: target, from: self)
            }
        }
    }

    private func updateRootView() {
        hostingView?.rootView = makeRootView()
    }
}

private struct NativeSegmentedPickerView: View {
    let labels: [String]
    let selectedSegment: Int
    let isEnabled: Bool
    let tint: Color
    let controlSize: SwiftUI.ControlSize
    let onChange: (Int) -> Void

    var body: some View {
        Picker(
            "",
            selection: Binding(
                get: { selectedSegment },
                set: { onChange($0) }
            )
        ) {
            ForEach(labels.indices, id: \.self) { index in
                Text(labels[index]).tag(index)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .tint(tint)
        .controlSize(controlSize)
        .disabled(!isEnabled)
    }
}

private final class NativeSegmentedControl: NSView {
    var selectedSegment: Int = 0 {
        didSet {
            updateRootView()
        }
    }

    weak var target: AnyObject?
    var action: Selector?
    var tint: Color = .accentColor {
        didSet {
            updateRootView()
        }
    }
    var controlSize: NSControl.ControlSize = .regular {
        didSet {
            updateRootView()
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 116, height: 30)
    }

    var isEnabled: Bool = true {
        didSet {
            updateRootView()
        }
    }

    private let labels: [String]
    private var hostingView: NSHostingView<NativeSegmentedPickerView>?

    init(labels: [String]) {
        self.labels = labels
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.labels = []
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        let host = NSHostingView(rootView: makeRootView())
        host.translatesAutoresizingMaskIntoConstraints = false
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(host)
        hostingView = host

        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func makeRootView() -> NativeSegmentedPickerView {
        NativeSegmentedPickerView(
            labels: labels,
            selectedSegment: selectedSegment,
            isEnabled: isEnabled,
            tint: tint,
            controlSize: swiftUIControlSize(from: controlSize)
        ) { [weak self] selected in
            guard let self,
                  labels.indices.contains(selected) else {
                return
            }

            selectedSegment = selected
            if let action {
                NSApp.sendAction(action, to: target, from: self)
            }
        }
    }

    private func updateRootView() {
        hostingView?.rootView = makeRootView()
    }
}

private final class WelcomeWindowController: NSWindowController {
    private let settings: AppSettings
    private let durationPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let displayPolicyControl = NativeSegmentedControl(labels: ["Sleep", "Stay on"])
    private let awakeSwitch = NativeSwitchControl()
    private let lidSwitch = NativeSwitchControl()
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
        let quitButton = makeFooterButton(title: "Quit Don't Stop", action: #selector(quitPressed))
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(quitButton)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 34),
            quitButton.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            quitButton.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            quitButton.topAnchor.constraint(equalTo: row.topAnchor),
            quitButton.bottomAnchor.constraint(equalTo: row.bottomAnchor)
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

private struct TerminalCommand {
    let name: String
    let minutes: Int?
    let reason: String
    let display: Bool?
}

private final class AwakeController {
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

private struct SleepTimerSnapshot {
    let battery: Int?
    let ac: Int?
}

private final class LidAssistController {
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

private final class StateStore {
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

private final class CommandInbox {
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

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
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
                self?.rebuildMenu()
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

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
