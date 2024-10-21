import Accelerate
import AppleArchive
import Compression
import ConsoleKit
import Foundation
import System

class LoggingArchiveStream: ArchiveStreamProtocol {
    private let wrappedStream: ArchiveStream
    private var totalBytesRead: Int64 = 0
    private var totalBytesWritten: Int64 = 0
    private let progressCallback: (Int64, Int64) -> Void

    init(wrappedStream: ArchiveStream, progressCallback: @escaping (Int64, Int64) -> Void) {
        self.wrappedStream = wrappedStream
        self.progressCallback = progressCallback
    }

    func writeHeader(_ header: ArchiveHeader) throws {
        // print("writeHeader \(header)")
        try wrappedStream.writeHeader(header)
    }

    func writeBlob(key: ArchiveHeader.FieldKey, from buffer: UnsafeRawBufferPointer) throws {
        try wrappedStream.writeBlob(key: key, from: buffer)
        totalBytesWritten += Int64(buffer.count)
        progressCallback(totalBytesRead, totalBytesWritten)
    }

    func readHeader() throws -> ArchiveHeader? {
        print("xxx readHeader")
        return try wrappedStream.readHeader()
    }

    func readBlob(key: ArchiveHeader.FieldKey, into buffer: UnsafeMutableRawBufferPointer) throws {
        try wrappedStream.readBlob(key: key, into: buffer)
        totalBytesRead += Int64(buffer.count)
        progressCallback(totalBytesRead, totalBytesWritten)
    }
    // func read(

    func cancel() {
        wrappedStream.cancel()
    }

    func close() throws {
        try wrappedStream.close()
    }
}

func archiveDirectory(
    sourcePath: FilePath, destPath: FilePath, compression: ArchiveCompression,
    progressCallback: @escaping (Int64, Int64) -> Void
)
    throws -> Int64
{
    guard
        let writeFileStream = ArchiveByteStream.fileStream(
            path: destPath,
            mode: .writeOnly,
            options: [.create],
            permissions: FilePermissions(rawValue: 0o644))
    else {
        return 0
    }
    defer {
        try? writeFileStream.close()
    }

    //  let filterArchive = ArchiveStream.fil
    guard
        let compressStream: ArchiveByteStream = ArchiveByteStream.compressionStream(
            using: compression,
            // selectUsing: f,
            writingTo: writeFileStream)
    else { return 0 }
    defer {
        try? compressStream.close()
    }

    guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressStream) else {
        return 0
    }
    defer {
        try? encodeStream.close()
    }
    guard let keySet = ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM")
    else {
        return 0
    }
    let loggingStream = LoggingArchiveStream(
        wrappedStream: encodeStream,
        progressCallback: progressCallback)
    let customStream = ArchiveStream.customStream(instance: loggingStream)
    try customStream?.writeDirectoryContents(
        // selected:
        archiveFrom: sourcePath,
        keySet: keySet
    )
    let fileSize =
        try FileManager.default.attributesOfItem(atPath: destPath.string)[.size] as! UInt64
    return Int64(fileSize)

    // Create a new ArchiveStream from the logging stream
    // let customStream = ArchiveStream.customStream(instance: loggingStream)
    // customStream

    // encodeStream count bytes written
    // try encodeStream.writeDirectoryContents(
    //     archiveFrom: sourcePath,
    //     keySet: keySet
    // )
}

// let
let compStrEnum = CompressionAlgorithm.allCases.map { "\($0.rawValue)" }
final class Compress: Command {
    struct Signature: CommandSignature {
        @Option(
            name: "algo", short: "a",
            help: "Compression algorithm",
            completion: .values(compStrEnum.map { String($0) })
        )
        var algo: String?

        @Flag(name: "color", short: "c", help: "Enables colorized output")
        var color: Bool
        @Flag(name: "override", short: "f", help: "override")
        var override: Bool
        @Flag(name: "progress", short: "g", help: "progress")
        var progress: Bool
        @Flag(name: "rm", help: "progress")
        var toremove: Bool

        @Flag(name: "safe", short: "s", help: "saff")
        var safe: Bool
        @Option(
            name: "dest", short: "d",
            help: "Custom dest for the loading bar\nUse a comma-separated list")
        var dest: String?

        @Argument(
            name: "source", help: "The source directory to compress", completion: .directories())
        var source: String
    }

    var help: String {
        "A demonstration of what ConsoleKit can do"
    }

    func run(using context: CommandContext, signature: Signature) throws {

        let sourceURL = URL(fileURLWithPath: signature.source)
        let algostr = signature.algo ?? "lzfse"

        if signature.algo != nil {
            if !CompressionAlgorithm.allCases.contains(where: { $0.rawValue == algostr }) {
                context.console.error(
                    "Invalid compression algorithm \(signature.algo!), options \(compStrEnum)")
                return
            }
        }
        // let algo = CompressionAlgorithm(rawValue: algostr)?.archiveCompression

        let compAlgorithm = CompressionAlgorithm(rawValue: algostr) ?? .lzfse

        let directoryExists = FileManager.default.fileExists(atPath: sourceURL.path)
        if !directoryExists {
            context.console.error("The source directory does not exist.")
            return
        }
        let destExtension = signature.algo != nil ? "\(algostr).aar" : "aar"
        let destURL =
            signature.dest != nil
            ? URL(fileURLWithPath: signature.dest!) : sourceURL.appendingPathExtension(destExtension)
        // print("destURL: \(destURL.path)")
        let destExists = FileManager.default.fileExists(atPath: destURL.path)
        if destExists {
            if !signature.override || signature.dest != nil {
                context.console.error("The \(destURL.path) already exists.")
                return
            }
            try FileManager.default.trashItem(at: destURL, resultingItemURL: nil)
        }
        if signature.safe {
            let confirmed = context.console.confirm(
                "Compress \(sourceURL.path) to \(destURL.path)?")
            if !confirmed {
                context.console.info("Aborting.")
                return
            }
        }
        let dirURLtotalSize = sizeOfDirectory(at: sourceURL)
        let xtotalSize = Int64(dirURLtotalSize ?? 0)
        context.console.activityBarWidth = 35
        let foo = console.xprogressBar(title: destURL.lastPathComponent)
        let pcallback = { (read: Int64, written: Int64) in
            foo.activity.bytesWritten = written
            foo.activity.totalSize = xtotalSize
            foo.activity.currentProgress = Double(written) / Double(xtotalSize)
        }
        do {
            foo.start(refreshRate: 50)
            let destSize = try archiveDirectory(
                sourcePath: FilePath(sourceURL.path),
                destPath: FilePath(destURL.path),
                compression: compAlgorithm.archiveCompression,
                progressCallback: pcallback
            )
            let ratio = round(Double(destSize) / Double(foo.activity.bytesWritten) * 1000) / 1000
            foo.activity.title +=
                " - \(round(Date().timeIntervalSince(foo.activity.startTime)*1000)/1000)s"
            foo.succeed()
            let fromx = ByteCountFormatter.string(
                fromByteCount: foo.activity.bytesWritten, countStyle: .file)
            let tox = ByteCountFormatter.string(fromByteCount: destSize, countStyle: .file)
            context.console.info("\(fromx) -> \(tox) (\(ratio.formatted(.percent)) %)")
            if signature.toremove {
                context.console.success("cleaning up \(sourceURL.path)")
                try FileManager.default.trashItem(at: sourceURL, resultingItemURL: nil)
            }
        } catch {
            context.console.error("Failed to compress: \(error.localizedDescription)")
        }
    }
}
