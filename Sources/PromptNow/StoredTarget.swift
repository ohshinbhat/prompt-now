import Foundation

struct StoredTarget: Codable, Equatable {
    var displayName: String
    var appName: String
    var bundleIdentifier: String?
    var processIdentifier: Int32?
    var windowTitle: String?
}
