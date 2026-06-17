import XCTest
@testable import DontStopCore

final class SudoersAuthorizationTests: XCTestCase {
    func testSudoersLineIsScopedToExactDisableSleepCommands() {
        let line = SudoersAuthorization.sudoersLine(user: "builduser")

        XCTAssertEqual(
            line,
            "builduser ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
        )
        XCTAssertFalse(line.contains("ALL: ALL"))
        XCTAssertFalse(line.contains("pmset *"))
        XCTAssertFalse(line.contains("/bin/sh"))
    }

    func testSudoersPathIsValidForSudoersDirectory() {
        XCTAssertEqual(SudoersAuthorization.sudoersPath, "/etc/sudoers.d/dont-stop-disablesleep")
        XCTAssertFalse((SudoersAuthorization.sudoersPath as NSString).lastPathComponent.contains("."))
    }

    func testEscapesSudoersUserNameSeparators() {
        XCTAssertEqual(
            SudoersAuthorization.escapedUserName("build user@mac"),
            "build\\ user\\@mac"
        )
    }
}

final class LidSleepStateTests: XCTestCase {
    func testSerializesAndParsesMarker() {
        let marker = LidSleepState(enabledAt: "2026-06-13T08:00:00Z")

        XCTAssertEqual(
            LidSleepState.parse(marker.serialized),
            LidSleepState(mode: "disablesleep", enabledAt: "2026-06-13T08:00:00Z")
        )
    }

    func testRejectsMarkerWithoutMode() {
        XCTAssertNil(LidSleepState.parse("enabledAt=2026-06-13T08:00:00Z\n"))
    }
}

final class SafetyCopyTests: XCTestCase {
    func testAppleSiliconCaveatMentionsPowerAndAirflow() {
        let caveat = DontStopPowerPolicy.appleSiliconLidCaveat.lowercased()

        XCTAssertTrue(caveat.contains("apple silicon"))
        XCTAssertTrue(caveat.contains("power"))
        XCTAssertTrue(caveat.contains("airflow"))
    }
}
