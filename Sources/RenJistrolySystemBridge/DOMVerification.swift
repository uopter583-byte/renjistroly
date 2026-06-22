import Foundation
import RenJistrolyModels

/// Before/after DOM snapshot comparison for verifying action outcomes.
/// Ported from FSB's DOM verification patterns.
public struct DOMVerification {
    /// JS that takes a compact DOM snapshot of interactive elements.
    public static func snapshotScript() -> String {
        """
        (function() {
            var els = document.querySelectorAll('button, a, input, textarea, select, [role="button"], [role="link"], [role="textbox"]');
            var snap = [];
            for (var i = 0; i < els.length && i < 80; i++) {
                var el = els[i];
                var rect = el.getBoundingClientRect();
                if (rect.width === 0 && rect.height === 0) continue;
                var text = (el.textContent || '').trim().substring(0, 120);
                var value = el.value || '';
                var tag = el.tagName.toLowerCase();
                var cls = (el.className || '').substring(0, 60);
                snap.push({
                    t: tag,
                    c: cls,
                    txt: text,
                    v: value.substring(0, 60),
                    x: Math.round(rect.x),
                    y: Math.round(rect.y),
                    w: Math.round(rect.width),
                    h: Math.round(rect.height)
                });
            }
            return JSON.stringify({count: snap.length, elements: snap, ts: Date.now()});
        })()
        """
    }

    /// Compare two DOM snapshots and detect meaningful changes.
    public static func diff(before: String, after: String) -> DOMDiffResult {
        var changes: [String] = []
        var hasChange = false

        guard let beforeData = before.data(using: .utf8),
              let afterData = after.data(using: .utf8),
              let beforeObj = try? JSONSerialization.jsonObject(with: beforeData) as? [String: Any],
              let afterObj = try? JSONSerialization.jsonObject(with: afterData) as? [String: Any] else {
            return DOMDiffResult(hasChange: false, changes: ["无法解析快照"], elementCountChange: 0)
        }

        let beforeEls = beforeObj["elements"] as? [[String: Any]] ?? []
        let afterEls = afterObj["elements"] as? [[String: Any]] ?? []
        let beforeCount = beforeEls.count
        let afterCount = afterEls.count
        let countDelta = afterCount - beforeCount

        if countDelta != 0 {
            changes.append("元素数量变化: \(beforeCount) → \(afterCount) (\(countDelta > 0 ? "+" : "")\(countDelta))")
            hasChange = true
        }

        // Compare first 30 elements for attribute/position changes
        let compareCount = min(30, beforeEls.count, afterEls.count)
        for i in 0..<compareCount {
            let b = beforeEls[i]
            let a = afterEls[i]
            let bTag = b["t"] as? String ?? ""
            let aTag = a["t"] as? String ?? ""

            // Different element at this position — page structure changed
            if bTag != aTag {
                if i < 5 {
                    changes.append("结构变化: [\(i)] \(bTag) → \(aTag)")
                }
                hasChange = true
                continue
            }

            let bText = b["txt"] as? String ?? ""
            let aText = a["txt"] as? String ?? ""
            if bText != aText {
                changes.append("文本变化: <\(bTag)>[\(i)] \"\(bText.prefix(40))\" → \"\(aText.prefix(40))\"")
                hasChange = true
            }

            let bVal = b["v"] as? String ?? ""
            let aVal = a["v"] as? String ?? ""
            if bVal != aVal && !bVal.isEmpty {
                changes.append("值变化: <\(bTag)>[\(i)] value changed")
                hasChange = true
            }

            let bX = b["x"] as? Int ?? 0
            let aX = a["x"] as? Int ?? 0
            let bY = b["y"] as? Int ?? 0
            let aY = a["y"] as? Int ?? 0
            if abs(bX - aX) > 5 || abs(bY - aY) > 5 {
                changes.append("位置变化: <\(bTag)>[\(i)] (\(bX),\(bY)) → (\(aX),\(aY))")
                hasChange = true
            }
        }

        return DOMDiffResult(
            hasChange: hasChange,
            changes: Array(changes.prefix(15)),
            elementCountChange: countDelta
        )
    }
}

public struct DOMDiffResult: Sendable, Codable, Equatable {
    public var hasChange: Bool
    public var changes: [String]
    public var elementCountChange: Int

    public init(hasChange: Bool, changes: [String], elementCountChange: Int) {
        self.hasChange = hasChange
        self.changes = changes
        self.elementCountChange = elementCountChange
    }
}
