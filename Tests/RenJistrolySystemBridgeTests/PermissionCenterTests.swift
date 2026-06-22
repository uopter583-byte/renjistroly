import XCTest
@testable import RenJistrolySystemBridge

func testSystemPermissionKindsCoverRequiredMacPermissions() {
    let kinds = Set(SystemPermissionKind.allCases)

    XCTAssertTrue(kinds.contains(.accessibility))
    XCTAssertTrue(kinds.contains(.microphone))
    XCTAssertTrue(kinds.contains(.speechRecognition))
    XCTAssertTrue(kinds.contains(.screenRecording))
    XCTAssertTrue(kinds.contains(.appleEvents))
}

func testSystemPermissionKindsHaveSettingsURLs() {
    for kind in SystemPermissionKind.allCases {
        XCTAssertTrue(kind.settingsURL != nil)
    }
}

func testPermissionStatusGrantedFlag() {
    XCTAssertTrue(SystemPermissionStatus.granted.isGranted)
    XCTAssertFalse(SystemPermissionStatus.denied.isGranted)
    XCTAssertFalse(SystemPermissionStatus.notDetermined.isGranted)
    XCTAssertFalse(SystemPermissionStatus.unknown.isGranted)
}

func testAppleEventsPermissionIsUnknown() async {
    let center = PermissionCenter()
    let check = await center.checkSystemPermission(.appleEvents)
    XCTAssertTrue(check.kind == .appleEvents)
    XCTAssertTrue(check.status == .unknown)
}

func testCheckSystemPermissionsReturnsFiveChecks() async {
    let center = PermissionCenter()
    let checks = await center.checkSystemPermissions()
    XCTAssertTrue(checks.count == 5)
    let kinds = Set(checks.map(\.kind))
    XCTAssertTrue(kinds.count == 5)
}
