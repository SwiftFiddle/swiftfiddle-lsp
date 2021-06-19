import Vapor

public func configure(_ app: Application) throws {
    app.http.server.configuration.supportPipelining = true
    app.http.server.configuration.requestDecompression = .enabled
    app.http.server.configuration.responseCompression = .enabled

    app.lifecycle.use(ShutdownHandler())
    
    try routes(app)
}

struct ShutdownHandler: LifecycleHandler {
    func shutdown(_ application: Application) {
        languageServer.stop()
    }
}
