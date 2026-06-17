import Foundation

public enum DontStopPowerPolicy {
    public static let pmsetPath = "/usr/bin/pmset"
    public static let sudoPath = "/usr/bin/sudo"
    public static let sudoersPath = "/etc/sudoers.d/dont-stop-disablesleep"

    public static let appleSiliconLidCaveat = "Apple Silicon lid sleep is partly hardware-gated. Reliability is best on power, with airflow, and even better with an external display."
    public static let compactLidCaveat = "Best on power with airflow"
    public static let lidHeatWarning = "Heat risk; power recommended"

    public static var disablesleepOnCommand: String {
        "\(pmsetPath) -a disablesleep 1"
    }

    public static var disablesleepOffCommand: String {
        "\(pmsetPath) -a disablesleep 0"
    }
}

public enum SudoersAuthorization {
    public static let sudoersPath = DontStopPowerPolicy.sudoersPath

    public static func escapedUserName(_ value: String) -> String {
        var escaped = ""
        for character in value {
            switch character {
            case " ", "\t", "\\", ",", ":", "=", "@":
                escaped.append("\\")
                escaped.append(character)
            default:
                escaped.append(character)
            }
        }
        return escaped
    }

    public static func sudoersLine(user: String) -> String {
        let escapedUser = escapedUserName(user)
        return "\(escapedUser) ALL=(root) NOPASSWD: \(DontStopPowerPolicy.disablesleepOnCommand), \(DontStopPowerPolicy.disablesleepOffCommand)"
    }
}

public struct LidSleepState: Equatable {
    public let mode: String
    public let enabledAt: String?

    public init(mode: String = "disablesleep", enabledAt: String? = nil) {
        self.mode = mode
        self.enabledAt = enabledAt
    }

    public var serialized: String {
        var lines = ["mode=\(mode)"]
        if let enabledAt, !enabledAt.isEmpty {
            lines.append("enabledAt=\(enabledAt)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func parse(_ text: String) -> LidSleepState? {
        var values: [String: String] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let separator = rawLine.firstIndex(of: "=") else {
                continue
            }
            let key = String(rawLine[..<separator])
            let value = String(rawLine[rawLine.index(after: separator)...])
            values[key] = value
        }

        guard let mode = values["mode"], !mode.isEmpty else {
            return nil
        }

        return LidSleepState(mode: mode, enabledAt: values["enabledAt"])
    }
}
