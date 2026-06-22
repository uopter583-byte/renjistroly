import Foundation
import RenJistrolyXPC

@main
struct HelperMain {
    static func main() {
        let service = HelperService()
        let listener = NSXPCListener.service()
        listener.delegate = service
        listener.resume()
    }
}
