import Accelerate
import AppleArchive
import Compression
import ConsoleKit
import Foundation
import System

func expandArchive(
    archiveFilePath: FilePath, decompressPath: FilePath,
    progressCallback: @escaping (Int64, Int64) -> Void
) throws {
    guard
        let readFileStream = ArchiveByteStream.fileStream(
            path: archiveFilePath,
            mode: .readOnly,
            options: [],
            permissions: FilePermissions(rawValue: 0o644))
        // readFileStream.
    else {
        console.error("Unable to create create folder")
        return
    }
    defer {
        try? readFileStream.close()
    }
    if !FileManager.default.fileExists(atPath: decompressPath.string) {
        do {
            try FileManager.default.createDirectory(
                atPath: decompressPath.string,
                withIntermediateDirectories: false)
        } catch {
            fatalError("Unable to create destination directory.")
        }
    } else {
        console.error("Unable to create destination directory.")
        throw ArchiveError.ioError
    }
    guard let decompressStream = ArchiveByteStream.decompressionStream(readingFrom: readFileStream)
    else {
        console.error("Unable to create decompressStream stream")
        return
    }
    defer {
        try? decompressStream.close()
    }
    guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressStream) else {
        print("unable to create decode stream")
        return
    }
    defer {
        try? decodeStream.close()
    }
    guard
        let extractStream = ArchiveStream.extractStream(
            extractingTo: decompressPath,
            flags: [])
    else {
        console.error("Unable to create extract stream")
        return
    }
    defer {
        try? extractStream.close()
    }
    let loggingStream = LoggingArchiveStream(
        wrappedStream: extractStream,
        progressCallback: progressCallback)
    let customStream = ArchiveStream.customStream(instance: loggingStream)!
    // try customStream?.(
    //     // selected:
    //     archiveFrom: sourcePath,
    //     keySet: keySet
    // )
    // decodeStream.
    let res = try ArchiveStream.process(readingFrom: decodeStream, writingTo: customStream)
    print("res: \(res)")

}

final class Expand: Command {
    // public let compStrEnum = CompressionAlgorithm.allCases.map { "\($0.rawValue)" }
    struct Signature: CommandSignature {
        // @Flag(name: "algorithm", short: "a", help: "Compression algorithm")
        // @Option(name: "algorithm", short: "a", help: "Compression algorithm", completion: c)
        // var algorithm: String
        // @Flag(name: "algorithm", short: "a", help: "Compression algorithm")
        // var algorithm: String
        // options: lzfse, lz4, zlib, lzma, lzbitmap
        // @Option(
        //     name: "algorithm", short: "a",
        //     help: "Compression algorithm",
        //     completion: .values(compStrEnum.map { String($0) })
        // )
        // var algo: String?

        // @Flag(name: "color", short: "c", help: "Enables colorized output")
        // var color: Bool
        @Flag(name: "override", short: "f", help: "override")
        var override: Bool
        @Flag(name: "progress", short: "g", help: "progress")
        var progress: Bool
        @Flag(name: "rm", help: "progress")
        var toremove: Bool

        // @Flag(name: "safe", short: "s", help: "saff")
        // var safe: Bool
        @Option(
            name: "dest", short: "d",
            help: "Custom dest for the loading bar\nUse a comma-separated list")
        var dest: String?

        @Argument(
            name: "source", help: "The source directory to compress", completion: .directories())
        var source: String
        // init() {
        // print("xxxxx \(compStrEnum)")
        // self.
        // }
        // @Argument(name: "destination", help: "The destination directory to compress", default: ".")
        // var destination: String

        // init() {}
    }

    var help: String {
        "A demonstration of what ConsoleKit can do"
    }

    func run(using context: CommandContext, signature: Signature) throws {

        let sourceURL = URL(fileURLWithPath: signature.source)

        let archiveExts = [
            "tgz", "aar", "zip", "jar", "war", "ear", "sar", "rar", "7z", "tar", "tar.gz",
            "tar.bz2", "tar.xz", "tgz", "tbz", "txz", "zipx", "apk", "ipa", "pkg", "dmg", "iso",
            "img", "bin", "tzst", "tgz", "tgxz", "tbz2", "txz", "tar.lz", "tar.lzma", "tar.zst",
            "lzma",
        ]
        let isArchiveFile = archiveExts.contains(sourceURL.pathExtension.lowercased())
        if !isArchiveFile {
            context.console.error("Not an archive file.")
            exit(0)
        }
        let destURL =
            signature.dest != nil
            ? URL(fileURLWithPath: signature.dest!) : URL(fileURLWithPath: sourceURL.path).deletingPathExtension()
        if signature.override {
            console.confirmOverride = true
        }
        console.info("Destination: \(destURL.path)")
        let allreadyExists = FileManager.default.fileExists(atPath: destURL.path)
        if allreadyExists {
            if console.confirm("Overwright and Remove \(destURL.path) ?") == false {
                context.console.info("Aborting.")
                exit(0)
            }
            try FileManager.default.trashItem(at: destURL, resultingItemURL: nil)
        }

        func run(loadingBar: ActivityIndicator<LoadingBar>) {

            loadingBar.start(refreshRate: 25)
            do {
                try expandArchive(
                    archiveFilePath: FilePath(sourceURL.path),
                    decompressPath: FilePath(destURL.path),
                    progressCallback: { (read: Int64, written: Int64) in
                        // let currentProgress = Double(written) / Double(sourceSize)
                        // console.activityBarWidth = 20 + Int(currentProgress * 2)
                        // loadingBar.activity.newActivity(
                        if written % 100 == 0 {
                            let humanReadableSize = ByteCountFormatter.string(
                                fromByteCount: written, countStyle: .file)
                            let fefe = 10 - humanReadableSize.count
                            let padding = String(repeating: " ", count: fefe)
                            let filename = destURL.lastPathComponent
                            loadingBar.activity.title = "\(filename) \(humanReadableSize)\(padding)"
                        }
                    }
                )
                loadingBar.succeed()
                context.console.success("unpacked to \(destURL.path)")
                if signature.toremove {
                    context.console.success("cleaning up \(sourceURL.path)")
                    try FileManager.default.trashItem(at: sourceURL, resultingItemURL: nil)
                    // context.console.success("removed \(sourceURL.path)")
                }
            } catch {
                loadingBar.fail()
                context.console.error("Failed to decompress: \(error.localizedDescription)")
            }
        }
        run(loadingBar: context.console.loadingBar(title: "UnPacking ..."))
        return

    }
}
