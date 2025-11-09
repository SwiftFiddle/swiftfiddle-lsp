import Foundation
import LanguageServerProtocol
import LanguageServerProtocolTransport

final class LanguageServer {
    let diagnosticsPublisher: @Sendable (PublishDiagnosticsNotification) -> Void

    private let serverProcess = Process()
    private let clientToServer = Pipe()
    private let serverToClient = Pipe()

    private var instance: LanguageServer?

    private let serverPath: String?

    private lazy var connection = JSONRPCConnection(
        name: "clangd",
        protocol: .lspProtocol,
        inFD: serverToClient.fileHandleForReading,
        outFD: clientToServer.fileHandleForWriting
    )

    init(serverPath: String? = nil, diagnosticsPublisher: @Sendable @escaping (PublishDiagnosticsNotification) -> Void = { _ in }) {
        self.serverPath = serverPath
        self.diagnosticsPublisher = diagnosticsPublisher
        instance = self
    }

    func start() throws {
        let launchPath: String
        if let serverPath = serverPath {
            launchPath = serverPath
        } else {
            #if os(macOS)
            launchPath =
                "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp"
            #else
            launchPath = "/usr/bin/sourcekit-lsp"
            #endif
        }

        connection.start(receiveHandler: Client(diagnosticsPublisher: diagnosticsPublisher))

        serverProcess.executableURL = URL(fileURLWithPath: launchPath)
        serverProcess.arguments = [
            "-Xswiftc", "-enable-bare-slash-regex",
        ]

        serverProcess.standardOutput = serverToClient
        serverProcess.standardInput = clientToServer
        serverProcess.terminationHandler = { [weak self] process in
            self?.connection.close()
        }

        try serverProcess.run()
    }

    func stop() {
        sendShutdownRequest { [weak self] _ in
            self?.sendExitNotification()
            self?.instance = nil
        }
    }

    func sendInitializeRequest(workspacePath: String, completion: @escaping (Result<InitializeRequest.Response, ResponseError>) -> Void) {
        let rootURI = URL(fileURLWithPath: workspacePath)

        let request = InitializeRequest(
            rootURI: DocumentURI(rootURI),
            capabilities: ClientCapabilities(
                textDocument: TextDocumentClientCapabilities(
                    completion: TextDocumentClientCapabilities.Completion(
                        completionItem: TextDocumentClientCapabilities.Completion.CompletionItem(
                            snippetSupport: true
                        )
                    )
                )
            ),
            workspaceFolders: [WorkspaceFolder(uri: DocumentURI(rootURI))]
        )
        _ = connection.send(request) {
            completion($0)
        }
    }

    func sendInitializedNotification() {
        connection.send(InitializedNotification())
    }

    func sendDidOpenNotification(documentPath: String, text: String) {
        let identifier = URL(fileURLWithPath: documentPath)
        let document = TextDocumentItem(
            uri: DocumentURI(identifier),
            language: .swift,
            version: 1,
            text: text
        )
        connection.send(DidOpenTextDocumentNotification(textDocument: document))
    }

    func sendDidChangeNotification(documentPath: String, text: String, version: Int) {
        let identifier = URL(fileURLWithPath: documentPath)
        connection.send(
            DidChangeTextDocumentNotification(
                textDocument: VersionedTextDocumentIdentifier(DocumentURI(identifier), version: version),
                contentChanges: [TextDocumentContentChangeEvent(range: nil, rangeLength: nil, text: text)],
                forceRebuild: nil
            )
        )
    }

    func sendDidCloseNotification(documentPath: String) {
        let identifier = URL(fileURLWithPath: documentPath)
        connection.send(
            DidCloseTextDocumentNotification(textDocument: TextDocumentIdentifier(DocumentURI(identifier)))
        )
    }

    func sendDocumentSymbolRequest(documentPath: String, completion: @escaping (Result<DocumentSymbolRequest.Response, ResponseError>) -> Void) {
        let identifier = URL(fileURLWithPath: documentPath)

        let documentSymbolRequest = DocumentSymbolRequest(
            textDocument: TextDocumentIdentifier(DocumentURI(identifier))
        )
        _ = connection.send(documentSymbolRequest) {
            completion($0)
        }
    }

    func sendCompletionRequest(documentPath: String, line: Int, character: Int, prefix: String? = nil, completion: @escaping (Result<CompletionRequest.Response, ResponseError>) -> Void) {
        let identifier = URL(fileURLWithPath: documentPath)

        let completionRequest = CompletionRequest(
            textDocument: TextDocumentIdentifier(DocumentURI(identifier)),
            position: Position(line: line, utf16index: character),
            context:CompletionContext(triggerKind: .invoked)
        )
        _ = connection.send(completionRequest) {
            completion($0)
        }
    }

    func sendHoverRequest(documentPath: String, line: Int, character: Int, completion: @escaping (Result<HoverRequest.Response, ResponseError>) -> Void) {
        let identifier = URL(fileURLWithPath: documentPath)

        let hoverRequest = HoverRequest(
            textDocument: TextDocumentIdentifier(DocumentURI(identifier)),
            position: Position(line: line, utf16index: character)
        )
        _ = connection.send(hoverRequest) {
            completion($0)
        }
    }

    func sendDefinitionRequest(documentPath: String, line: Int, character: Int, completion: @escaping (Result<DefinitionRequest.Response, ResponseError>) -> Void) {
        let identifier = URL(fileURLWithPath: documentPath)

        let definitionRequest = DefinitionRequest(
            textDocument: TextDocumentIdentifier(DocumentURI(identifier)),
            position: Position(line: line, utf16index: character)
        )
        _ = connection.send(definitionRequest) {
            completion($0)
        }
    }

    func sendReferencesRequest(documentPath: String, line: Int, character: Int, completion: @escaping (Result<ReferencesRequest.Response, ResponseError>) -> Void) {
        let identifier = URL(fileURLWithPath: documentPath)

        let referencesRequest = ReferencesRequest(
            textDocument: TextDocumentIdentifier(DocumentURI(identifier)),
            position: Position(line: line, utf16index: character),
            context: ReferencesContext(includeDeclaration: false)
        )
        _ = connection.send(referencesRequest) {
            completion($0)
        }
    }

    func sendDocumentHighlightRequest(documentPath: String, line: Int, character: Int, completion: @escaping (Result<DocumentHighlightRequest.Response, ResponseError>) -> Void) {
        let identifier = URL(fileURLWithPath: documentPath)

        let documentHighlightRequest = DocumentHighlightRequest(
            textDocument: TextDocumentIdentifier(DocumentURI(identifier)),
            position: Position(line: line, utf16index: character)
        )
        _ = connection.send(documentHighlightRequest) {
            completion($0)
        }
    }

    func sendShutdownRequest(completion: @escaping (Result<ShutdownRequest.Response, ResponseError>) -> Void) {
        let request = ShutdownRequest()
        _ = connection.send(request) {
            completion($0)
        }
    }

    func sendExitNotification() {
        connection.send(ExitNotification())
        serverProcess.terminate()
    }
}

private final class Client: MessageHandler {
  let diagnosticsPublisher: @Sendable (PublishDiagnosticsNotification) -> Void

  init(diagnosticsPublisher: @Sendable @escaping (PublishDiagnosticsNotification) -> Void) {
    self.diagnosticsPublisher = diagnosticsPublisher
  }

  func handle(_ notification: some LanguageServerProtocol.NotificationType) {
    if let notification = notification as? PublishDiagnosticsNotification {
      diagnosticsPublisher(notification)
    }
  }
  
  func handle<Request>(_ request: Request, id: LanguageServerProtocol.RequestID, reply: @escaping (LanguageServerProtocol.LSPResult<Request.Response>) -> Void) where Request : LanguageServerProtocol.RequestType {}
}
