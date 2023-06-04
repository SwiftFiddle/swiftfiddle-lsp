import Vapor

public func configure(_ app: Application) throws {
  app.http.server.configuration.requestDecompression = .enabled
  app.http.server.configuration.responseCompression = .enabled
  app.http.server.configuration.supportPipelining = true
  try routes(app)
}
