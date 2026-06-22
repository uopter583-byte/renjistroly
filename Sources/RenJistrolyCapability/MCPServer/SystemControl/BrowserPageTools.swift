import Foundation
import AppKit
import RenJistrolyModels
import RenJistrolySystemBridge
import OSLog

// MARK: - WebPageStructureTool

public struct WebPageStructureTool: MCPTool {
    public let definition = ToolDefinition(
        name: "webpage_structure",
        description: "获取浏览器页面 DOM 结构，支持 CSS 选择器过滤和文字提取",
        parameters: [
            .init(name: "selector", type: .string, description: "CSS 选择器过滤，为空返回 body 下所有可见元素", required: false),
            .init(name: "include_hidden", type: .string, description: "是否包含隐藏元素: true/false，默认 false", required: false),
            .init(name: "app", type: .string, description: "浏览器应用: Safari/Chrome，默认 Safari", required: false),
            .init(name: "action", type: .string, description: "操作: inspect(检查) / extract(提取文本) / screenshot(截图+DOM)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "extract"
        let browser = arguments["app"] ?? "Safari"
        let isChrome = browser.localizedCaseInsensitiveContains("chrome")
        let appName = isChrome ? "Google Chrome" : "Safari"
        let bridge = AppleScriptBridge()
        do {
            let output: String
            if action == "extract" {
                let sc = isChrome ? "tell application \"\(appName)\" to set t to text of active tab of front window" :
                                    "tell application \"\(appName)\" to set t to text of current tab of front window"
                let r = try await bridge.run(sc + "\nreturn t")
                output = r.stringValue ?? "（页面内容为空）"
            } else if action == "inspect" {
                let sel = (arguments["selector"] ?? "").replacingOccurrences(of: "\"", with: "\\\"")
                let includeHidden = (arguments["include_hidden"] ?? "false").lowercased() == "true"
                let visFilter = includeHidden ? "false" : "true"
                let js: String
                if sel.isEmpty {
                    js = "(function(){var a=document.querySelectorAll('body *'),r=[];for(var i=0;i<a.length&&r.length<60;i++){var e=a[i],rect=e.getBoundingClientRect(),h=rect.width===0||rect.height===0;if(\(visFilter)&&h)continue;var t=e.tagName.toLowerCase(),x=(e.textContent||'').trim().substring(0,80);if(!x&&!e.id)continue;r.push({t:t,tx:x.substring(0,60),id:e.id||'',cl:(typeof e.className=='string'?e.className:'').substring(0,40),v:!h})}return JSON.stringify({total:a.length,shown:r.length,elements:r})})()"
                } else {
                    js = "(function(){var a=document.querySelectorAll(\"\(sel)\"),r=[];for(var i=0;i<a.length&&r.length<60;i++){var e=a[i],rect=e.getBoundingClientRect(),h=rect.width===0||rect.height===0;if(\(visFilter)&&h)continue;r.push({t:e.tagName.toLowerCase(),tx:(e.textContent||'').trim().substring(0,80),id:e.id||'',v:!h})}return JSON.stringify({total:a.length,shown:r.length,elements:r})})()"
                }
                let esc = js.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
                let jsc = isChrome ? "tell application \"\(appName)\" to set r to execute javascript \"\(esc)\" in active tab of front window" :
                                     "tell application \"\(appName)\" to set r to do JavaScript \"\(esc)\" in current tab of front window"
                let raw = try await bridge.run(jsc + "\nreturn r as text")
                if let d = (raw.stringValue ?? "{}").data(using: .utf8), let dict = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                    let total = dict["total"] as? Int ?? 0
                    let els = dict["elements"] as? [[String: Any]] ?? []
                    var lines = ["DOM 结构: \(total) 元素, 显示 \(els.count) 个"]
                    for (i, el) in els.enumerated() {
                        var p = ["<\(el["t"] ?? "?")>"]
                        if let v = el["v"] as? Bool, !v { p.append("(hidden)") }
                        if let id = el["id"] as? String, !id.isEmpty { p.append("#\(id)") }
                        if let tx = el["tx"] as? String, !tx.isEmpty { p.append("「\(tx)」") }
                        lines.append("  \(i+1). \(p.joined(separator: " "))")
                    }
                    output = lines.joined(separator: "\n")
                } else {
                    output = raw.stringValue ?? "{}"
                }
            } else {
                output = "使用 screen_context 查看截图"
            }
            Task { await AgentEventBus.shared.publish(.browser(.domQueried(selector: arguments["selector"] ?? "", resultCount: output.count))) }
            return ToolCallResult(id: UUID().uuidString, output: output)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "获取页面失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - BrowserFormTool

public struct BrowserFormTool: MCPTool {
    public let definition = ToolDefinition(
        name: "browser_form",
        description: "浏览器表单填充与提交操作。通过 JavaScript 操作 DOM 元素，支持填充表单字段、提交表单和清除字段内容。",
        parameters: [
            .init(name: "action", type: .string, description: "操作: fill(填充) / submit(提交) / clear(清除)"),
            .init(name: "selector", type: .string, description: "CSS 选择器，指向要操作的表单元素"),
            .init(name: "value", type: .string, description: "填充值 (action=fill 时需要)", required: false),
            .init(name: "app", type: .string, description: "浏览器应用: Safari/Chrome，默认 Safari", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action", isError: true)
        }
        guard let selector = arguments["selector"], !selector.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: selector", isError: true)
        }
        let browser = arguments["app"] ?? "Safari"
        let isChrome = browser.localizedCaseInsensitiveContains("chrome")
        let appName = isChrome ? "Google Chrome" : "Safari"
        let value = arguments["value"] ?? ""
        let bridge = AppleScriptBridge()

        do {
            let result: String
            switch action {
            case "fill":
                guard !value.isEmpty else {
                    return ToolCallResult(id: UUID().uuidString, output: "填充操作需要提供 value", isError: true)
                }
                result = try await fillField(bridge: bridge, appName: appName, isChrome: isChrome, selector: selector, value: value)
                guard result == "filled" else {
                    let msg = result == "error:element_not_found" ? "未找到选择器对应的元素: \(selector)" :
                              result == "error:unsupported_element" ? "不支持的元素类型" : "填充失败: \(result)"
                    return ToolCallResult(id: UUID().uuidString, output: msg, isError: true)
                }
                return ToolCallResult(id: UUID().uuidString, output: "已填充: \(selector)")

            case "submit":
                result = try await submitForm(bridge: bridge, appName: appName, isChrome: isChrome, selector: selector)
                guard result == "submitted" else {
                    let msg = result == "error:element_not_found" ? "未找到元素: \(selector)" :
                              result == "error:no_form_found" ? "未找到可提交的表单" : "提交失败: \(result)"
                    return ToolCallResult(id: UUID().uuidString, output: msg, isError: true)
                }
                return ToolCallResult(id: UUID().uuidString, output: "已提交表单: \(selector)")

            case "clear":
                result = try await clearField(bridge: bridge, appName: appName, isChrome: isChrome, selector: selector)
                guard result == "cleared" else {
                    let msg = result == "error:element_not_found" ? "未找到元素: \(selector)" : "清除失败: \(result)"
                    return ToolCallResult(id: UUID().uuidString, output: msg, isError: true)
                }
                return ToolCallResult(id: UUID().uuidString, output: "已清除: \(selector)")

            default:
                return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
            }
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "表单操作失败: \(error.localizedDescription)", isError: true)
        }
    }

    private func fillField(bridge: AppleScriptBridge, appName: String, isChrome: Bool, selector: String, value: String) async throws -> String {
        let sel = selector.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let val = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
        let js = """
        (function(){
            var el=document.querySelector("\(sel)");
            if(!el)return'error:element_not_found';
            var t=el.tagName.toLowerCase();
            if(t=='input'||t=='textarea'){el.value="\(val)";el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));return'filled';}
            if(el.isContentEditable){el.textContent="\(val)";return'filled';}
            if(t=='select'){el.value="\(val)";el.dispatchEvent(new Event('change',{bubbles:true}));return'filled';}
            return'error:unsupported_element';
        })()
        """
        return try await execJS(bridge: bridge, appName: appName, isChrome: isChrome, js: js)
    }

    private func submitForm(bridge: AppleScriptBridge, appName: String, isChrome: Bool, selector: String) async throws -> String {
        let sel = selector.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let js = """
        (function(){
            var el=document.querySelector("\(sel)");
            if(!el)return'error:element_not_found';
            if(el.tagName.toLowerCase()=='form'){el.submit();return'submitted';}
            var f=el.closest('form');if(f){f.submit();return'submitted';}
            return'error:no_form_found';
        })()
        """
        return try await execJS(bridge: bridge, appName: appName, isChrome: isChrome, js: js)
    }

    private func clearField(bridge: AppleScriptBridge, appName: String, isChrome: Bool, selector: String) async throws -> String {
        let sel = selector.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let js = """
        (function(){
            var el=document.querySelector("\(sel)");
            if(!el)return'error:element_not_found';
            var t=el.tagName.toLowerCase();
            if(t=='input'||t=='textarea'){el.value='';el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));return'cleared';}
            if(el.isContentEditable){el.textContent='';return'cleared';}
            if(t=='select'){el.selectedIndex=-1;el.dispatchEvent(new Event('change',{bubbles:true}));return'cleared';}
            return'error:unsupported_element';
        })()
        """
        return try await execJS(bridge: bridge, appName: appName, isChrome: isChrome, js: js)
    }

    private func execJS(bridge: AppleScriptBridge, appName: String, isChrome: Bool, js: String) async throws -> String {
        let esc = js.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
        let script: String
        if isChrome {
            script = "tell application \"\(appName)\" to set r to execute javascript \"\(esc)\" in active tab of front window\nreturn r as text"
        } else {
            script = "tell application \"\(appName)\" to set r to do JavaScript \"\(esc)\" in current tab of front window\nreturn r as text"
        }
        let result = try await bridge.run(script)
        return result.stringValue ?? "{}"
    }
}
