import Foundation
import OSLog

public extension Logger {
    static let app = Logger(subsystem: "com.renjistroly", category: "app")
    static let engine = Logger(subsystem: "com.renjistroly", category: "conversation")
    static let networking = Logger(subsystem: "com.renjistroly", category: "networking")
    static let system = Logger(subsystem: "com.renjistroly", category: "system")
    static let screen = Logger(subsystem: "com.renjistroly", category: "screen")
    static let memory = Logger(subsystem: "com.renjistroly", category: "memory")
    static let tools = Logger(subsystem: "com.renjistroly", category: "tools")
    static let security = Logger(subsystem: "com.renjistroly", category: "security")
}
