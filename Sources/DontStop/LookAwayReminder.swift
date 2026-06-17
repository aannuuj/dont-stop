import AppKit

final class LookAwayEyesView: NSView {
    private var phase: CGFloat = 0
    private var animationTimer: Timer?

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopAnimation()
        } else {
            startAnimation()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let eyeSize = NSSize(width: 76, height: 54)
        let gap: CGFloat = 18
        let totalWidth = eyeSize.width * 2 + gap
        let leftOrigin = NSPoint(x: bounds.midX - totalWidth / 2, y: bounds.midY - eyeSize.height / 2)
        let rightOrigin = NSPoint(x: leftOrigin.x + eyeSize.width + gap, y: leftOrigin.y)
        let offset = NSPoint(
            x: CGFloat(sin(Double(phase))) * 10,
            y: CGFloat(cos(Double(phase * 0.72))) * 5
        )

        drawEye(in: NSRect(origin: leftOrigin, size: eyeSize), pupilOffset: offset)
        drawEye(in: NSRect(origin: rightOrigin, size: eyeSize), pupilOffset: offset)
    }

    private func drawEye(in rect: NSRect, pupilOffset: NSPoint) {
        let eyePath = NSBezierPath(ovalIn: rect)
        NSColor.white.withAlphaComponent(0.94).setFill()
        eyePath.fill()

        NSColor.white.withAlphaComponent(0.22).setStroke()
        eyePath.lineWidth = 1.5
        eyePath.stroke()

        let maxPupilOffsetX = rect.width * 0.16
        let maxPupilOffsetY = rect.height * 0.12
        let pupilCenter = NSPoint(
            x: rect.midX + max(-maxPupilOffsetX, min(maxPupilOffsetX, pupilOffset.x)),
            y: rect.midY + max(-maxPupilOffsetY, min(maxPupilOffsetY, pupilOffset.y))
        )
        let pupilRect = NSRect(
            x: pupilCenter.x - 11,
            y: pupilCenter.y - 11,
            width: 22,
            height: 22
        )

        NSColor(calibratedWhite: 0.05, alpha: 0.96).setFill()
        NSBezierPath(ovalIn: pupilRect).fill()

        NSColor.white.withAlphaComponent(0.78).setFill()
        NSBezierPath(ovalIn: NSRect(x: pupilRect.minX + 5, y: pupilRect.maxY - 8, width: 5, height: 5)).fill()
    }

    private func startAnimation() {
        guard animationTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += 0.035
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

final class GlassOverlayButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    private var isPressing = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        isPressing = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        isPressing = true
        updateAppearance()
        super.mouseDown(with: event)
        isPressing = false
        updateAppearance()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        wantsLayer = true
        controlSize = .large
        font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)
        imagePosition = .imageLeading
        imageHugsTitle = true
        bezelStyle = .regularSquare
        setButtonType(.momentaryPushIn)
        updateAppearance()
    }

    private func updateAppearance() {
        guard let layer else {
            return
        }

        let alpha: CGFloat = isPressing ? 0.30 : (isHovering ? 0.24 : 0.16)
        layer.backgroundColor = NSColor.white.withAlphaComponent(alpha).cgColor
        layer.borderColor = NSColor.white.withAlphaComponent(isHovering ? 0.34 : 0.20).cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 19
        if #available(macOS 10.15, *) {
            layer.cornerCurve = .continuous
        }
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = isPressing ? 0.12 : 0.28
        layer.shadowRadius = isHovering ? 18 : 14
        layer.shadowOffset = NSSize(width: 0, height: -6)

        let title = attributedTitle.string.isEmpty ? "Skip break" : attributedTitle.string
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: MonoPalette.text
            ]
        )
        contentTintColor = MonoPalette.text
    }
}

final class LookAwayOverlayController {
    private var windows: [NSWindow] = []
    private var countdownLabels: [NSTextField] = []
    private var countdownTimer: Timer?
    private var screenParametersObserver: NSObjectProtocol?
    private var remainingSeconds = 0

    var onDismiss: (() -> Void)?

    func show(duration: Int = lookAwayDurationSeconds) {
        dismiss(notify: false)
        remainingSeconds = duration
        startScreenParametersObserver()
        rebuildOverlayWindows()
        updateCountdownLabels()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func dismiss() {
        dismiss(notify: true)
    }

    @objc private func skipPressed() {
        dismiss()
    }

    private func tick() {
        remainingSeconds -= 1

        if remainingSeconds <= 0 {
            dismiss()
            return
        }

        updateCountdownLabels()
    }

    private func dismiss(notify: Bool) {
        countdownTimer?.invalidate()
        countdownTimer = nil
        stopScreenParametersObserver()
        remainingSeconds = 0
        countdownLabels.removeAll()

        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()

        if notify {
            onDismiss?()
        }
    }

    private func startScreenParametersObserver() {
        stopScreenParametersObserver()

        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildOverlayWindows()
        }
    }

    private func stopScreenParametersObserver() {
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
            self.screenParametersObserver = nil
        }
    }

    private func rebuildOverlayWindows() {
        guard remainingSeconds > 0 else {
            return
        }

        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        countdownLabels.removeAll()

        for screen in NSScreen.screens {
            let window = makeOverlayWindow(for: screen)
            window.orderFrontRegardless()
            windows.append(window)
        }

        updateCountdownLabels()
    }

    private func makeOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.setFrame(screen.frame, display: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.contentView = makeOverlayView()
        return window
    }

    private func makeOverlayView() -> NSView {
        let blurView = NSVisualEffectView()
        blurView.material = .hudWindow
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.backgroundColor = NSColor(calibratedWhite: 0.0, alpha: 0.34).cgColor

        let eyes = LookAwayEyesView()
        let title = makeOverlayLabel("Look away", size: 54, weight: .semibold, color: MonoPalette.text)
        let body = makeOverlayLabel("Relax your eyes for 30 seconds.", size: 20, weight: .medium, color: MonoPalette.textSecondary)
        let countdown = makeOverlayLabel("", size: 44, weight: .medium, color: MonoPalette.text)
        countdownLabels.append(countdown)

        let skipButton = GlassOverlayButton(title: "Skip break", target: self, action: #selector(skipPressed))

        let stack = NSStackView(views: [eyes, title, body, countdown, skipButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16

        blurView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: blurView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: blurView.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: blurView.trailingAnchor, constant: -40),
            eyes.widthAnchor.constraint(equalToConstant: 182),
            eyes.heightAnchor.constraint(equalToConstant: 82),
            skipButton.widthAnchor.constraint(equalToConstant: 136),
            skipButton.heightAnchor.constraint(equalToConstant: 38)
        ])

        return blurView
    }

    private func makeOverlayLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.maximumNumberOfLines = 0
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.shadow = {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
            shadow.shadowBlurRadius = 18
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            return shadow
        }()
        return label
    }

    private func updateCountdownLabels() {
        let text = "\(max(0, remainingSeconds))"
        for label in countdownLabels {
            label.stringValue = text
        }
    }
}

final class LookAwayReminderController {
    private let settings: AppSettings
    private let overlayController = LookAwayOverlayController()
    private var reminderTimer: Timer?
    private var isRunning = false

    init(settings: AppSettings) {
        self.settings = settings
        overlayController.onDismiss = { [weak self] in
            self?.scheduleNext()
        }
    }

    func start() {
        reminderTimer?.invalidate()
        reminderTimer = nil

        guard settings.lookAwayRemindersEnabled else {
            isRunning = false
            overlayController.dismiss()
            return
        }

        isRunning = true
        scheduleNext()
    }

    func stop() {
        isRunning = false
        reminderTimer?.invalidate()
        reminderTimer = nil
        overlayController.dismiss()
    }

    func settingsDidChange() {
        if settings.lookAwayRemindersEnabled {
            start()
        } else {
            stop()
        }
    }

    func showNow() {
        isRunning = settings.lookAwayRemindersEnabled
        reminderTimer?.invalidate()
        reminderTimer = nil
        overlayController.show()
    }

    private func scheduleNext() {
        reminderTimer?.invalidate()
        reminderTimer = nil

        guard settings.lookAwayRemindersEnabled else {
            return
        }
        guard isRunning else {
            return
        }

        reminderTimer = Timer.scheduledTimer(withTimeInterval: lookAwayIntervalSeconds, repeats: false) { [weak self] _ in
            self?.showNow()
        }
    }
}
