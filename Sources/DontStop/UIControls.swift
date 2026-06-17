import AppKit
import SwiftUI

final class ArcBackdropView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        NSGradient(colors: [
            MonoPalette.canvasTop,
            MonoPalette.canvasBottom
        ])?.draw(in: bounds, angle: 260)
    }
}

final class ActionTileControl: NSControl {
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

func isDarkAppearance(_ appearance: NSAppearance) -> Bool {
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
}

func adaptiveColor(for view: NSView, light: NSColor, dark: NSColor) -> NSColor {
    isDarkAppearance(view.effectiveAppearance) ? dark : light
}

class AppearanceAwareVisualEffectView: NSVisualEffectView {
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

final class GlassPanelView: AppearanceAwareVisualEffectView {
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

final class AppearanceAwareView: NSView {
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

func swiftUIControlSize(from controlSize: NSControl.ControlSize) -> SwiftUI.ControlSize {
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

struct NativeSwitchView: View {
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

final class NativeSwitchControl: NSView {
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

struct NativeSegmentedPickerView: View {
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

final class NativeSegmentedControl: NSView {
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
