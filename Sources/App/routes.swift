import Vapor
import LanguageServerProtocol

let languageServer: LanguageServer = {
    let languageServer = LanguageServer()
    try? languageServer.start()
    return languageServer
}()

func routes(_ app: Application) throws {

    app.webSocket { (req, ws) in
        let uuid = UUID().uuidString

        struct DidOpenRequest: Codable {
            let method: String
            let version: String
            let code: String
            let sessionId: String
        }
        typealias DidChangeRequest = DidOpenRequest
        struct DidCloseRequest: Codable {
            let method: String
            let sessionId: String
        }

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
        struct CompletionResponse: Codable {
            let method: String
            let id: Int
            let position: Position
            let value: LanguageServerProtocol.CompletionRequest.Response?
        }

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let fileManager = FileManager()
        let temporaryDirectory = URL(fileURLWithPath: "\(app.directory.resourcesDirectory)temp")
        let workspacePath = temporaryDirectory.appendingPathComponent(uuid, isDirectory: true).path
        do {
            try fileManager.copyItem(atPath: "\(app.directory.resourcesDirectory)ProjectTemplate/", toPath: workspacePath)
        } catch {
            _ = ws.close(code: .goingAway)
            return
        }

        _ = ws.onClose.always { _ in
            try? fileManager.removeItem(atPath: workspacePath)
        }

        do {
            let metadata = try String(contentsOf: URL(fileURLWithPath: "\(workspacePath)/.build/debug.yaml"), encoding: .utf8)
                .replacingOccurrences(
                    of: "/build-packages/ProjectTemplate/.build",
                    with: workspacePath
                )
            try metadata.write(toFile: "\(workspacePath)/.build/debug.yaml", atomically: false, encoding: .utf8)
        } catch {
            _ = ws.close(code: .goingAway)
            return
        }

        let sourceRoot = "\(workspacePath)/Sources/_Workspace/"
        let documentPath = "\(sourceRoot)File.swift"
        var documentVersion = 0

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
                languageServer.sendDidCloseNotification(documentPath: documentPath)
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
                guard let request = try? decoder.decode(HoverRequest.self, from: data) else { return }
                languageServer.sendCompletionRequest(
                    documentPath: documentPath, line: request.row, character: request.column
                ) { (result) in
                    req.logger.info("\(result)")
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
            default:
                break
            }
        }
    }
}
