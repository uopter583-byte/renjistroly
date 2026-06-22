import Foundation

@inline(__always)
func withCStringPointers<R>(
    _ strings: [String],
    _ body: ([UnsafePointer<CChar>]) throws -> R
) rethrows -> R {
    var pointers: [UnsafePointer<CChar>] = []

    func recurse(_ index: Int) throws -> R {
        if index == strings.count {
            return try body(pointers)
        }

        return try strings[index].withCString { pointer in
            pointers.append(pointer)
            defer { pointers.removeLast() }
            return try recurse(index + 1)
        }
    }

    return try recurse(0)
}
