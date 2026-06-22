import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolySystemBridge

// MARK: - TTL expiry

func testElementSnapshotExpired() async {
    let registry = ElementRegistry(ttl: -1)
    await registry.replace(elements: [], appBundleID: nil, appName: nil)
    do {
        _ = try await registry.element(for: "0")
        XCTFail("should have thrown")
    } catch let error as ElementRegistryError {
        if case .snapshotExpired = error {} else {
            XCTFail("expected snapshotExpired, got \(error)")
        }
    } catch {
        XCTFail("wrong error type: \(error)")
    }
}

func testElementNotFound() async {
    let registry = ElementRegistry()
    await registry.replace(elements: [], appBundleID: nil, appName: nil)
    do {
        _ = try await registry.element(for: "42")
        XCTFail("should have thrown")
    } catch let error as ElementRegistryError {
        if case .elementNotFound("42") = error {} else {
            XCTFail("expected elementNotFound(42), got \(error)")
        }
    } catch {
        XCTFail("wrong error type")
    }
}

func testElementAppMismatch() async {
    let registry = ElementRegistry()
    await registry.replace(elements: [], appBundleID: "com.apple.Safari", appName: "Safari")
    do {
        _ = try await registry.element(for: "0", expectedApp: "Finder")
        XCTFail("should have thrown")
    } catch let error as ElementRegistryError {
        if case .appMismatch(let expected, let actual) = error {
            XCTAssertTrue(expected == "Finder")
            XCTAssertTrue(actual == "Safari")
        } else {
            XCTFail("wrong error case: \(error)")
        }
    } catch {
        XCTFail("wrong error type")
    }
}

func testElementNoAppMismatchWhenExpectedAppEmpty() async {
    let registry = ElementRegistry()
    await registry.replace(elements: [], appBundleID: nil, appName: nil)
    do {
        _ = try await registry.element(for: "42")
        XCTFail("should have thrown")
    } catch let error as ElementRegistryError {
        if case .elementNotFound = error {} else {
            XCTFail("expected elementNotFound, got \(error)")
        }
    } catch {
        XCTFail("wrong error type")
    }
}

// MARK: - metadata

func testMetadataReturnsNilForEmptyRegistry() async {
    let registry = ElementRegistry()
    let meta = await registry.metadata(for: "unknown")
    XCTAssertTrue(meta == nil)
}

// MARK: - clear

func testClearCausesSnapshotExpired() async {
    let registry = ElementRegistry()
    await registry.replace(elements: [], appBundleID: "com.test", appName: "Test")
    await registry.clear()
    do {
        _ = try await registry.element(for: "0")
        XCTFail("should have thrown after clear")
    } catch let error as ElementRegistryError {
        if case .snapshotExpired = error {} else {
            XCTFail("expected snapshotExpired, got \(error)")
        }
    } catch {
        XCTFail("wrong error type")
    }
}

// MARK: - ElementRegistryError descriptions (LocalizedError)

func testErrorDescriptions() {
    let expired = ElementRegistryError.snapshotExpired
    XCTAssertTrue(expired.errorDescription?.contains("过期") == true)

    let notFound = ElementRegistryError.elementNotFound("xyz")
    XCTAssertTrue(notFound.errorDescription?.contains("xyz") == true)

    let mismatch = ElementRegistryError.appMismatch(expected: "AppA", actual: "AppB")
    XCTAssertTrue(mismatch.errorDescription?.contains("AppA") == true)
    XCTAssertTrue(mismatch.errorDescription?.contains("AppB") == true)
}
