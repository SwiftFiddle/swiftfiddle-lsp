import Foundation
import LanguageServerProtocol
import Vapor

func routes(_ app: Application) throws {
    app.get {  _ in healthCheck() }
    app.get("health") { _ in healthCheck() }
    app.get("lang-server") { _ in healthCheck() }
    app.get("lang-server", "health") { _ in healthCheck() }

    func healthCheck() -> [String: String] { ["status": "pass"] }

    app.webSocket("lang-server", "api") { (req, ws) in
        languageServer(req, ws)
    }

    func languageServer(_ req: Vapor.Request, _ ws: WebSocket) {
        let uuid = UUID().uuidString

        struct DidOpenRequest: Codable {
            let method: String
            let code: String
            let sessionId: String
        }
        struct DidCloseRequest: Codable {
            let method: String
            let sessionId: String
        }
        typealias DidChangeRequest = DidOpenRequest

        struct HoverRequest: Codable {
            let method: String
            let id: Int
            let row: Int
            let column: Int
            let sessionId: String
        }
        struct HoverResponse: Codable {
            let method: String
            let id: Int
            let position: Position
            let value: LanguageServerProtocol.HoverRequest.Response
        }

        typealias CompletionRequest = HoverRequest
        struct CompletionResponse: Codable {
            let method: String
            let id: Int
            let position: Position
            let value: LanguageServerProtocol.CompletionRequest.Response?
        }

        struct DiagnosticsNotification: Codable {
            let method: String
            let value: PublishDiagnosticsNotification
        }

        struct FormatRequest: Codable {
            let method: String
            let code: String
        }
        struct FormatResponse: Codable {
            let method: String
            let value: String
        }

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let workspacePath = temporaryDirectory.appendingPathComponent(uuid, isDirectory: true).path
        do {
            try copyWorkspace(
                atPath: "\(app.directory.resourcesDirectory)ProjectTemplate",
                toPath: workspacePath
            )
        } catch {
            req.logger.error("\(error.localizedDescription)")
            _ = ws.close(code: .unexpectedServerError)
            return
        }

        do {
            let metadata = try String(
                contentsOf: URL(fileURLWithPath: "\(workspacePath)/.build/debug.yaml"), encoding: .utf8
            )
            .replacingOccurrences(
                of: "/build/Resources/ProjectTemplate/.build",
                with: workspacePath
            )
            try metadata.write(toFile: "\(workspacePath)/.build/debug.yaml", atomically: false, encoding: .utf8)
        } catch {
            req.logger.error("\(error.localizedDescription)")
            _ = ws.close(code: .unexpectedServerError)
            return
        }

        let sourceRoot = "\(workspacePath)/Sources/App/"
        let documentPath = "\(sourceRoot)main.swift"
        var documentVersion = 0

        let diagnosticsPublisher = { (notification: PublishDiagnosticsNotification) in
            guard notification.uri.fileURL?.path == documentPath else { return }

            let diagnosticsNotification = DiagnosticsNotification(
                method: "diagnostics",
                value: notification
            )
            guard let data = try? encoder.encode(diagnosticsNotification) else { return }
            guard let json = String(data: data, encoding: .utf8) else { return }
            ws.send(json)
        }
        let languageServer = LanguageServer(diagnosticsPublisher: diagnosticsPublisher)

        do {
            try languageServer.start()
        } catch {
            req.logger.error("\(error.localizedDescription)")
            _ = ws.close(code: .unexpectedServerError)
            return
        }

        _ = ws.onClose.always { _ in
            do {
                languageServer.sendDidCloseNotification(documentPath: documentPath)
                languageServer.stop()
                try FileManager().removeItem(atPath: workspacePath)
            } catch {
                req.logger.error("\(error.localizedDescription)")
            }
        }

        ws.onText { (ws, text) in
            guard let data = text.data(using: .utf8) else { return }

            switch text {
            case _ where text.hasPrefix(#"{"method":"didOpen""#):
                guard let request = try? decoder.decode(DidOpenRequest.self, from: data) else { return }
                languageServer.sendInitializeRequest(workspacePath: workspacePath) { (result) in
                    switch result {
                    case .success:
                        languageServer.sendDidOpenNotification(documentPath: documentPath, text: request.code)
                    case .failure:
                        break
                    }
                }
            case _ where text.hasPrefix(#"{"method":"didChange""#):
                guard let request = try? decoder.decode(DidChangeRequest.self, from: data) else { return }
                documentVersion += 1
                languageServer.sendDidChangeNotification(documentPath: documentPath, text: request.code, version: documentVersion)
            case _ where text.hasPrefix(#"{"method":"didClose""#):
                break
            case _ where text.hasPrefix(#"{"method":"hover""#):
                guard let request = try? decoder.decode(HoverRequest.self, from: data) else { return }
                languageServer.sendHoverRequest(
                    documentPath: documentPath, line: request.row, character: request.column
                ) { (result) in
                    let value: LanguageServerProtocol.HoverRequest.Response
                    switch result {
                    case .success(let response):
                        if let response = response {
                            value = response
                        } else {
                            value = nil
                        }
                    case .failure:
                        value = nil
                    }
                    let hoverResponse = HoverResponse(
                        method: "hover",
                        id: request.id,
                        position: Position(line: request.row + 1, utf16index: request.column + 1),
                        value: value
                    )
                    guard let data = try? encoder.encode(hoverResponse) else { return }
                    guard let json = String(data: data, encoding: .utf8) else { return }
                    ws.send(json)
                }
            case _ where text.hasPrefix(#"{"method":"completion""#):
                guard let request = try? decoder.decode(CompletionRequest.self, from: data) else { return }
                languageServer.sendCompletionRequest(
                    documentPath: documentPath, line: request.row, character: request.column
                ) { (result) in
                    let value: LanguageServerProtocol.CompletionRequest.Response?
                    switch result {
                    case .success(let response):
                        value = response
                    case .failure:
                        value = nil
                    }
                    let completionResponse = CompletionResponse(
                        method: "completion",
                        id: request.id,
                        position: Position(line: request.row + 1, utf16index: request.column + 1),
                        value: value
                    )
                    guard let data = try? encoder.encode(completionResponse) else { return }
                    guard let json = String(data: data, encoding: .utf8) else { return }
                    ws.send(json)
                }
            case _ where text.hasPrefix(#"{"method":"format""#):
                guard let request = try? decoder.decode(FormatRequest.self, from: data) else { return }
                let source = request.code
                let output = format(source: source)
                let formatResponse = FormatResponse(method: "format", value: output)
                guard let data = try? encoder.encode(formatResponse) else { return }
                guard let json = String(data: data, encoding: .utf8) else { return }
                ws.send(json)
            default:
                break
            }
        }
    }

    func format(source: String) -> String {
        guard let input = source.data(using: .utf8) else {
            return source
        }

        let standardInput = Pipe()
        let standardOutput = Pipe()
        let standardError = Pipe()

        let fileHandle = standardInput.fileHandleForWriting
        fileHandle.write(input)
        do {
            try fileHandle.close()
        } catch {
            return source
        }

        let process = Process()
        let executableURL = URL(
            fileURLWithPath: app.directory.resourcesDirectory
        )
        .appendingPathComponent("formatter/.build/release/swift-format")
        process.executableURL = executableURL

        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = standardError

        process.launch()
        process.waitUntilExit()

        let data = standardOutput.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return source
        }

        return output
    }
}

private func copyWorkspace(atPath sourcePath: String, toPath destPath: String) throws {
    let fileManager = FileManager()
    try fileManager.copyItem(atPath: sourcePath, toPath: destPath)
}
