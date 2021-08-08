import Foundation
import SwiftFormat
import SwiftFormatConfiguration

final class Formatter {
    func format(source: String) throws -> String {
        let formatter = SwiftFormatter(configuration: Configuration())
        var output = ""
        try formatter.format(source: source, assumingFileURL: nil, to: &output)
        return output
    }
}
