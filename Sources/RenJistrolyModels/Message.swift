import Foundation

public enum MessageRole: String, Codable, Sendable, Hashable {
    case system
    case user
    case assistant
    case tool
}

public enum ContentBlock: Codable, Sendable, Hashable {
    case text(String)
    case image(ImageSource)
    case toolCall(ToolCallRequest)
    case toolResult(ToolCallResult)
    case file(FileReference)

    public enum ImageSource: Codable, Sendable, Hashable {
        case url(URL)
        case base64(String, mimeType: String)
        case filePath(String)
    }

    public struct FileReference: Codable, Sendable, Hashable {
        public let path: String
        public let language: String?
        public let snippet: String?

        public init(path: String, language: String? = nil, snippet: String? = nil) {
            self.path = path
            self.language = language
            self.snippet = snippet
        }
    }
}

public struct ToolCallRequest: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let arguments: [String: String]

    public init(id: String, name: String, arguments: [String: String]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

public struct ToolCallResult: Codable, Sendable, Hashable {
    public let id: String
    public let output: String
    public let isError: Bool

    public init(id: String, output: String, isError: Bool = false) {
        self.id = id
        self.output = output
        self.isError = isError
    }
}
