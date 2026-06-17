import AppKit
import Foundation

let appSupportName = "DontStop"
let lookAwayIntervalSeconds: TimeInterval = 25 * 60
let lookAwayDurationSeconds = 30
let agentSetupURL = URL(string: "https://github.com/aannuuj/dont-stop/blob/master/docs/agent-setup.md")!

enum MonoPalette {
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

func applicationSupportDirectory() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support", isDirectory: true)
        .appendingPathComponent(appSupportName, isDirectory: true)
}

struct DurationOption {
    let title: String
    let minutes: Int?

    var storedValue: Int {
        minutes ?? 0
    }
}

enum DurationOptions {
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

final class AppSettings {
    private enum Key {
        static let defaultDurationMinutes = "defaultDurationMinutes"
        static let deactivateOnSleep = "deactivateOnSleep"
        static let showWelcomeOnLaunch = "showWelcomeOnLaunch"
        static let lookAwayRemindersEnabled = "lookAwayRemindersEnabled"
        static let lidAssistWarningAccepted = "lidAssistWarningAccepted"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.defaultDurationMinutes: 0,
            Key.deactivateOnSleep: true,
            Key.showWelcomeOnLaunch: false,
            Key.lookAwayRemindersEnabled: false,
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

    var lookAwayRemindersEnabled: Bool {
        get { defaults.bool(forKey: Key.lookAwayRemindersEnabled) }
        set { defaults.set(newValue, forKey: Key.lookAwayRemindersEnabled) }
    }

    var lidAssistWarningAccepted: Bool {
        get { defaults.bool(forKey: Key.lidAssistWarningAccepted) }
        set { defaults.set(newValue, forKey: Key.lidAssistWarningAccepted) }
    }
}
