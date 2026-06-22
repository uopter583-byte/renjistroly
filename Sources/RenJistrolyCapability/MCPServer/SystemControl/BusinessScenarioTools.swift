import Foundation
import os
import RenJistrolyModels

// =============================================================================
// BusinessScenarioTools has been split into 4 files by business domain:
//
//   - SalesScenarioTools.swift     — CRM audit, field mapping, sales stages,
//                                    amount change confirmation, quote templates,
//                                    contract approval (tools 413, 416-418, 421-422)
//
//   - MarketingScenarioTools.swift — Chart OCR parsing, push confirmation,
//                                    CSV validation, CMS version management,
//                                    site confirmation, window verification,
//                                    baseline comparison (tools 429-435)
//
//   - FinanceScenarioTools.swift   — High risk confirmation, refund risk assessment,
//                                    reminders, production switch, data export masking,
//                                    dry-run preview (tools 408, 414, 424, 426-428)
//
//   - OperationsScenarioTools.swift — Session context, script strategy, permissions,
//                                     sentiment analysis, context isolation,
//                                     translation, OCR confidence, timezone check,
//                                     speaker diarization, multi-window fusion,
//                                     code review, git workflow, terminal session,
//                                     browser docs, project diagnosis
//                                     (tools 406-407, 409-412, 415, 420, 423,
//                                      425, 436-440)
//
// All original public API signatures remain unchanged.
// =============================================================================
