import Foundation

enum ZipArchive {
    static func createZip(from folder: URL, to zipURL: URL) throws {
        var target = zipURL
        if target.pathExtension.lowercased() != "zip" {
            target.appendPathExtension("zip")
        }

        try runDitto(arguments: [
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            folder.path,
            target.path
        ])
    }

    static func extractZip(_ zipURL: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try runDitto(arguments: [
            "-x",
            "-k",
            zipURL.path,
            destination.path
        ])
    }

    private static func runDitto(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ZipArchiveError.failed(message?.isEmpty == false ? message! : "ditto exited with status \(process.terminationStatus)")
        }
    }
}

enum ZipArchiveError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message
        }
    }
}
