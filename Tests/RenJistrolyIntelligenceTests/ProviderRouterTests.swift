import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - ProviderPreference properties

func testSelectableCasesExcludesCloudRealtime() {
    let cases = ProviderPreference.selectableCases
    XCTAssertTrue(!cases.contains(.cloudRealtime))
    XCTAssertTrue(cases.count == 7)
}

func testAllTitlesNonEmpty() {
    for pref in ProviderPreference.allCases {
        XCTAssertFalse(pref.title.isEmpty)
    }
}

func testAllImplementedExceptCloudRealtime() {
    for pref in ProviderPreference.allCases {
        if pref == .cloudRealtime {
            XCTAssertFalse(pref.isImplemented)
        } else {
            XCTAssertTrue(pref.isImplemented)
        }
    }
}

func testProviderPreferenceIDMatchesRawValue() {
    for pref in ProviderPreference.allCases {
        XCTAssertTrue(pref.id == pref.rawValue)
    }
}

func testClaudeCodeTitle() {
    XCTAssertTrue(ProviderPreference.claudeCode.title == "Claude Code")
}

func testDeepSeekTitle() {
    XCTAssertTrue(ProviderPreference.deepSeek.title == "DeepSeek")
}

func testLocalEndpointTitle() {
    XCTAssertTrue(ProviderPreference.localEndpoint.title == "本地端点")
}

func testQwenTitle() {
    XCTAssertTrue(ProviderPreference.qwen.title == "Qwen")
}

func testMoonshotTitle() {
    XCTAssertTrue(ProviderPreference.moonshot.title == "Moonshot")
}

func testAppleNativeTitle() {
    XCTAssertTrue(ProviderPreference.appleNative.title == "Apple 原生")
}

func testLocalFirstTitle() {
    XCTAssertTrue(ProviderPreference.localFirst.title == "本地优先")
}

func testCloudRealtimeTitle() {
    XCTAssertTrue(ProviderPreference.cloudRealtime.title == "云端实时")
}

// MARK: - ProviderPreference ↔ LLMProvider sync mapping

/// Maps ProviderPreference → LLMProvider (mirrors AssistantSessionController.syncActiveProvider).
private func mapPreferenceToProvider(_ pref: ProviderPreference) -> LLMProvider {
    switch pref {
    case .claudeCode: .claudeCodeCLI
    case .deepSeek: .deepseek
    case .qwen, .moonshot, .appleNative: .custom
    case .localEndpoint, .localFirst: .localMLX
    case .cloudRealtime: .anthropic
    }
}

/// Maps LLMProvider → ProviderPreference (mirrors syncControllerProvider in MenuBarView/SettingsView).
private func mapProviderToPreference(_ provider: LLMProvider) -> ProviderPreference {
    switch provider {
    case .claudeCodeCLI: .claudeCode
    case .deepseek: .deepSeek
    case .localMLX, .ollama: .localEndpoint
    case .custom: .localFirst
    default: .deepSeek
    }
}

func testProviderPreferenceToLLMProviderAllCases() {
    for pref in ProviderPreference.allCases {
        let llm = mapPreferenceToProvider(pref)
        // Every ProviderPreference must map to a valid LLMProvider
        XCTAssertTrue(LLMProvider.allCases.contains(llm),
                      "\(pref) → \(llm) not in LLMProvider.allCases")
    }
}

func testLLMProviderToProviderPreferenceAllCases() {
    for llm in LLMProvider.allCases {
        let pref = mapProviderToPreference(llm)
        XCTAssertTrue(ProviderPreference.allCases.contains(pref),
                      "\(llm) → \(pref) not in ProviderPreference.allCases")
    }
}

func testBidirectionalClaudeCodeMapping() {
    // Claude Code: .claudeCode ↔ .claudeCodeCLI
    XCTAssertEqual(mapPreferenceToProvider(.claudeCode), .claudeCodeCLI)
    XCTAssertEqual(mapProviderToPreference(.claudeCodeCLI), .claudeCode)
}

func testBidirectionalDeepSeekMapping() {
    // DeepSeek: .deepSeek ↔ .deepseek
    XCTAssertEqual(mapPreferenceToProvider(.deepSeek), .deepseek)
    XCTAssertEqual(mapProviderToPreference(.deepseek), .deepSeek)
}

func testBidirectionalLocalEndpointMapping() {
    // Local endpoint: .localEndpoint → .localMLX → .localEndpoint
    XCTAssertEqual(mapPreferenceToProvider(.localEndpoint), .localMLX)
    XCTAssertEqual(mapProviderToPreference(.localMLX), .localEndpoint)
}

func testBidirectionalLocalFirstMapping() {
    // Local first: .localFirst → .localMLX → .localEndpoint (asymmetric: .localFirst not round-trippable)
    XCTAssertEqual(mapPreferenceToProvider(.localFirst), .localMLX)
    XCTAssertEqual(mapProviderToPreference(.localMLX), .localEndpoint)
}

func testOllamaMapsToLocalEndpoint() {
    // Ollama has no forward mapping but reverse maps to localEndpoint
    XCTAssertEqual(mapProviderToPreference(.ollama), .localEndpoint)
}

func testCustomMapsToLocalFirst() {
    // All custom/hybrid providers map to .localFirst in reverse
    XCTAssertEqual(mapProviderToPreference(.custom), .localFirst)
}

func testQwenMoonshotAndAppleNativeAllMapToCustom() {
    XCTAssertEqual(mapPreferenceToProvider(.qwen), .custom)
    XCTAssertEqual(mapPreferenceToProvider(.moonshot), .custom)
    XCTAssertEqual(mapPreferenceToProvider(.appleNative), .custom)
}

func testCloudRealtimeMapsToAnthropic() {
    XCTAssertEqual(mapPreferenceToProvider(.cloudRealtime), .anthropic)
}

func testDefaultProviderMapping() {
    // Providers not explicitly listed in reverse mapping should go to .deepSeek
    for llm in LLMProvider.allCases {
        let pref = mapProviderToPreference(llm)
        switch llm {
        case .claudeCodeCLI, .deepseek, .localMLX, .ollama, .custom:
            break // explicitly handled
        default:
            XCTAssertEqual(pref, .deepSeek, "\(llm) should default to .deepSeek")
        }
    }
}
