import Foundation
import RenJistrolyModels

/// JS injection for classifying interactive element purpose and detecting sensitive fields.
/// Ported from FSB's purpose inference patterns.
public enum ElementPurposeInference {
    /// Returns JS script that classifies interactive elements by purpose and flags sensitive fields.
    public static func classificationScript() -> String {
        """
        (function() {
            var MAX = 80;
            var results = [];

            function classify(el) {
                var tag = el.tagName.toLowerCase();
                var type = (el.getAttribute('type') || '').toLowerCase();
                var name = (el.getAttribute('name') || '').toLowerCase();
                var id = (el.getAttribute('id') || '').toLowerCase();
                var placeholder = (el.getAttribute('placeholder') || '').toLowerCase();
                var ariaLabel = (el.getAttribute('aria-label') || '').toLowerCase();
                var text = (el.textContent || '').trim().toLowerCase();

                var purpose = 'unknown';
                var sensitive = false;

                var signals = [name, id, placeholder, ariaLabel, text].join(' ');

                // Sensitive field detection
                if (/password|secret|token|key|credential|auth|pwd|passwd|ssn|social.?security|cvv|cvc|pin|otp|2fa|mfa/.test(signals)) {
                    sensitive = true;
                    purpose = 'sensitive_input';
                }
                if (/credit.?card|cc.?num|card.?number|card.?cvv|card.?exp/.test(signals)) {
                    sensitive = true;
                    purpose = 'payment_sensitive';
                }

                // Purpose classification
                if (tag === 'button' || type === 'button' || type === 'submit') {
                    purpose = 'button';
                    if (/submit|save|send|confirm|ok|yes|done|go/.test(text)) purpose = 'submit';
                    if (/cancel|back|close|dismiss|no|delete|remove/.test(text)) purpose = 'dismiss';
                    if (/search|find|look.?up/.test(text)) purpose = 'search';
                    if (/next|continue|forward|proceed/.test(text)) purpose = 'next';
                    if (/prev|previous|backward|back/.test(text)) purpose = 'previous';
                } else if (tag === 'a') {
                    purpose = 'link';
                    if (/sign.?in|log.?in|login/.test(text)) purpose = 'login';
                    if (/sign.?up|register|create.?account/.test(text)) purpose = 'signup';
                    if (/logout|sign.?out/.test(text)) purpose = 'logout';
                } else if (tag === 'input' || tag === 'textarea') {
                    purpose = 'input';
                    if (type === 'email') purpose = 'email_input';
                    if (type === 'tel' || type === 'phone') purpose = 'phone_input';
                    if (type === 'url') purpose = 'url_input';
                    if (type === 'number') purpose = 'number_input';
                    if (type === 'search') purpose = 'search_input';
                    if (type === 'checkbox') purpose = 'checkbox';
                    if (type === 'radio') purpose = 'radio';
                    if (type === 'file') purpose = 'file_input';
                    if (type === 'range') purpose = 'slider';
                    if (type === 'date' || type === 'datetime-local') purpose = 'date_input';
                } else if (tag === 'select') {
                    purpose = 'dropdown';
                } else if (el.isContentEditable) {
                    purpose = 'editable';
                } else if (tag === 'form') {
                    purpose = 'form';
                }

                var rect = el.getBoundingClientRect();
                results.push({
                    tag: tag,
                    type: type,
                    name: name,
                    id: id,
                    purpose: purpose,
                    sensitive: sensitive,
                    visible: rect.width > 0 && rect.height > 0,
                    rect: { x: rect.x, y: rect.y, w: rect.width, h: rect.height },
                    className: (el.className || '').substring(0, 100)
                });
            }

            // Collect all interactive elements
            var selectors = 'button, a, input, textarea, select, [role="button"], [role="link"], [role="textbox"], [role="combobox"], [role="searchbox"], [role="checkbox"], [role="radio"], [tabindex]:not([tabindex="-1"]), [contenteditable="true"]';
            var elements = document.querySelectorAll(selectors);
            for (var i = 0; i < elements.length && results.length < MAX; i++) {
                classify(elements[i]);
            }

            return JSON.stringify({ count: results.length, elements: results });
        })()
        """
    }

    /// Parse the JS result into structured element info.
    public static func parseClassificationResult(_ json: String) -> [InteractiveElementInfo] {
        guard let data = json.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = raw["elements"] as? [[String: Any]] else {
            return []
        }
        return elements.compactMap { dict in
            guard let tag = dict["tag"] as? String else { return nil }
            return InteractiveElementInfo(
                tag: tag,
                type: dict["type"] as? String ?? "",
                name: dict["name"] as? String ?? "",
                id: dict["id"] as? String ?? "",
                purpose: dict["purpose"] as? String ?? "unknown",
                sensitive: dict["sensitive"] as? Bool ?? false,
                visible: dict["visible"] as? Bool ?? true,
                rect: nil
            )
        }
    }
}

public struct InteractiveElementInfo: Sendable, Codable {
    public let tag: String
    public let type: String
    public let name: String
    public let id: String
    public let purpose: String
    public let sensitive: Bool
    public let visible: Bool
    public let rect: String?

    public init(tag: String, type: String, name: String, id: String, purpose: String, sensitive: Bool, visible: Bool, rect: String?) {
        self.tag = tag
        self.type = type
        self.name = name
        self.id = id
        self.purpose = purpose
        self.sensitive = sensitive
        self.visible = visible
        self.rect = rect
    }
}
