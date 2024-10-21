import Accelerate
import AppleArchive
import Compression
import ConsoleKit
import Foundation
import System

enum CompressionAlgorithm: String, CaseIterable, RawRepresentable {
    case lzfse
    case lz4
    case zlib
    case lzma
    case lzbitmap
    case brotli
    case none

    public var archiveCompression: ArchiveCompression {
        switch self {
        case .lzfse:
            return .lzfse
        case .lz4:
            return .lz4
        case .zlib:
            return .zlib
        case .lzma:
            return .lzma
        case .lzbitmap:
            if #available(macOS 13.3, *) {
                return .lzbitmap
            } else {
                return .lz4
                // Fallback on earlier versions
            }
        case .brotli:
            return .init(algo: .brotli)
        case .none:
            return .none
        }
    }
}
func sizeOfDirectory(at url: URL) -> Int? {
    guard
        let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey])
    else { return nil }
    var size = 0
    for case let fileURL as URL in enumerator {
        guard let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            continue
        }
        size += fileSize
    }
    return size
}

public struct XProgressBar: ActivityBar {
    /// See `ActivityBar`.
    public var title: String

    public var totalSize: Int64 = 1000
    public var bytesWritten: Int64 = 0
    /// Controls how the `ProgressBar` is rendered.
    ///
    /// Valid values are between 0 and 1.
    ///
    /// When `1`, the progress bar is full. When `0`, it is empty.
    public var currentProgress: Double
    public var startTime: Date = Date()

    public func renderActiveBar(tick: UInt, width: Int) -> ConsoleText {
        let current = min(max(currentProgress, 0.0), 1.0)
        let left = Int(current * Double(width))
        let right = width - left

        var barComponents: [String] = []
        // barComponents.append(" \(title) ")
        barComponents.append("[")
        barComponents.append(" \((round(current*100)/100).formatted(.percent))")
        barComponents.append("] ")

        barComponents.append(.init(repeating: "◼︎", count: Int(left)))
        barComponents.append(.init(repeating: " ", count: 1))
        barComponents.append(.init(Int(current * 100).isMultiple(of: 2) ? "🞣 " : "🞨 "))
        barComponents.append(.init(repeating: " ", count: Int(right)))
        barComponents.append("[")
        barComponents.append("read: \(bytesWritten.formatted(.byteCount(style: .binary)))")
        barComponents.append("]")

        return barComponents.joined(separator: "").consoleText(.info)
    }
}
extension Console {
    func xprogressBar(title: String, totalSize: Int64 = 0, targetQueue: DispatchQueue? = nil)
        -> ActivityIndicator<XProgressBar>
    {
        return XProgressBar(title: title, totalSize: 0, currentProgress: 0).newActivity(
            for: self, targetQueue: targetQueue)
    }
}
