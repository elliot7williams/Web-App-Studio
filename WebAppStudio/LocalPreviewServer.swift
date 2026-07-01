import Foundation
import Network

final class LocalPreviewServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var urlString = ""
    @Published private(set) var deviceURLString = ""
    @Published private(set) var statusMessage = "Stopped"

    private let queue = DispatchQueue(label: "WebAppStudio.LocalPreviewServer")
    private var listener: NWListener?
    private var rootURL: URL?

    var scanURLString: String {
        deviceURLString.isEmpty ? urlString : deviceURLString
    }

    @MainActor
    func toggle(document: WebAppDocument) {
        isRunning ? stop() : start(document: document)
    }

    @MainActor
    func start(document: WebAppDocument) {
        stop()

        do {
            let root = try materialize(document: document)
            let newListener = try NWListener(using: .tcp)

            rootURL = root
            listener = newListener
            statusMessage = "Starting local server..."

            newListener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }

            newListener.stateUpdateHandler = { [weak self, weak newListener] state in
                guard let self else { return }

                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        let port = newListener?.port?.rawValue ?? 0
                        let deviceURL = Self.localIPv4Address().map { "http://\($0):\(port)/" } ?? ""
                        self.isRunning = true
                        self.urlString = "http://127.0.0.1:\(port)/"
                        self.deviceURLString = deviceURL
                        self.statusMessage = "Serving \(document.appName)"
                        document.statusMessage = "Local server running at \(deviceURL.isEmpty ? self.urlString : deviceURL)"
                    case .failed(let error):
                        self.isRunning = false
                        self.urlString = ""
                        self.deviceURLString = ""
                        self.statusMessage = "Server failed: \(error.localizedDescription)"
                        document.statusMessage = self.statusMessage
                    case .cancelled:
                        self.isRunning = false
                        self.urlString = ""
                        self.deviceURLString = ""
                        self.statusMessage = "Stopped"
                    default:
                        break
                    }
                }
            }

            newListener.start(queue: queue)
        } catch {
            isRunning = false
            urlString = ""
            statusMessage = "Server failed: \(error.localizedDescription)"
            document.statusMessage = statusMessage
        }
    }

    @MainActor
    func refresh(document: WebAppDocument) {
        guard isRunning, let rootURL else {
            start(document: document)
            return
        }

        do {
            try writeExport(document: document, to: rootURL)
            statusMessage = "Refreshed \(document.appName)"
            document.statusMessage = "Refreshed local server at \(scanURLString)"
        } catch {
            statusMessage = "Refresh failed: \(error.localizedDescription)"
            document.statusMessage = statusMessage
        }
    }

    @MainActor
    func stop() {
        listener?.cancel()
        listener = nil
        rootURL = nil
        isRunning = false
        urlString = ""
        deviceURLString = ""
        statusMessage = "Stopped"
    }

    @MainActor
    private func materialize(document: WebAppDocument) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebAppStudioPreview-\(UUID().uuidString)", isDirectory: true)

        try writeExport(document: document, to: root)
        return root
    }

    @MainActor
    private func writeExport(document: WebAppDocument, to root: URL) throws {
        let fileManager = FileManager.default
        let generatedFiles = [
            "index.html",
            "manifest.webmanifest",
            "styles.css",
            "app.js",
            "README.md",
            "service-worker.js"
        ]

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        for fileName in generatedFiles {
            let target = root.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
        }

        let iconsFolder = root.appendingPathComponent("icons", isDirectory: true)
        if fileManager.fileExists(atPath: iconsFolder.path) {
            try fileManager.removeItem(at: iconsFolder)
        }
        try fileManager.createDirectory(at: iconsFolder, withIntermediateDirectories: true)

        for file in document.exportFiles {
            let target = root.appendingPathComponent(file.fileName)
            try file.contents.write(to: target, atomically: true, encoding: .utf8)
        }

        try WebAppIconRenderer.writeIcons(for: document, to: iconsFolder)
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self, weak connection] data, _, _, _ in
            guard let self, let connection else { return }

            let response = self.response(for: data)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func response(for data: Data?) -> Data {
        guard
            let data,
            let request = String(data: data, encoding: .utf8),
            let firstLine = request.components(separatedBy: "\r\n").first
        else {
            return httpResponse(status: "400 Bad Request", body: Data("Bad request".utf8), contentType: "text/plain; charset=utf-8")
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            return httpResponse(status: "400 Bad Request", body: Data("Bad request".utf8), contentType: "text/plain; charset=utf-8")
        }

        guard parts[0] == "GET" || parts[0] == "HEAD" else {
            return httpResponse(status: "405 Method Not Allowed", body: Data("Method not allowed".utf8), contentType: "text/plain; charset=utf-8")
        }

        let body = parts[0] == "HEAD" ? Data() : nil
        guard let fileURL = fileURL(for: String(parts[1])) else {
            return httpResponse(status: "404 Not Found", body: body ?? Data("Not found".utf8), contentType: "text/plain; charset=utf-8")
        }

        do {
            let fileData = try Data(contentsOf: fileURL)
            return httpResponse(
                status: "200 OK",
                body: body ?? fileData,
                contentType: contentType(for: fileURL.pathExtension),
                explicitLength: fileData.count
            )
        } catch {
            return httpResponse(status: "404 Not Found", body: body ?? Data("Not found".utf8), contentType: "text/plain; charset=utf-8")
        }
    }

    private func fileURL(for rawPath: String) -> URL? {
        guard let rootURL else { return nil }

        let pathOnly = rawPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? rawPath
        let decodedPath = pathOnly.removingPercentEncoding ?? pathOnly
        let normalizedPath = decodedPath == "/" ? "/index.html" : decodedPath
        let relativePath = normalizedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !relativePath.isEmpty, !relativePath.contains("..") else {
            return nil
        }

        return rootURL.appendingPathComponent(relativePath)
    }

    private func contentType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "html", "htm":
            return "text/html; charset=utf-8"
        case "css":
            return "text/css; charset=utf-8"
        case "js":
            return "text/javascript; charset=utf-8"
        case "json":
            return "application/json; charset=utf-8"
        case "webmanifest":
            return "application/manifest+json; charset=utf-8"
        case "png":
            return "image/png"
        case "svg":
            return "image/svg+xml"
        case "txt", "md":
            return "text/plain; charset=utf-8"
        default:
            return "application/octet-stream"
        }
    }

    private func httpResponse(status: String, body: Data, contentType: String, explicitLength: Int? = nil) -> Data {
        var response = Data()
        let headers = [
            "HTTP/1.1 \(status)",
            "Content-Type: \(contentType)",
            "Content-Length: \(explicitLength ?? body.count)",
            "Cache-Control: no-store",
            "Access-Control-Allow-Origin: *",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")

        response.append(Data(headers.utf8))
        response.append(body)
        return response
    }

    private static func localIPv4Address() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else {
            return nil
        }
        defer { freeifaddrs(interfaces) }

        var fallbackAddress: String?
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstInterface

        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }

            let interface = current.pointee
            guard
                interface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
                let name = String(validatingUTF8: interface.ifa_name)
            else {
                continue
            }

            var address = interface.ifa_addr.pointee
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                &address,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            guard result == 0 else { continue }

            let ipAddress = String(cString: hostname)
            guard !ipAddress.hasPrefix("127.") else { continue }

            if name == "en0" || name == "en1" {
                return ipAddress
            }

            fallbackAddress = fallbackAddress ?? ipAddress
        }

        return fallbackAddress
    }
}
