import SwiftUI

/// Cross-platform URL opener
func openURL(_ url: URL) {
    #if os(macOS)
    NSWorkspace.shared.open(url)
    #else
    UIApplication.shared.open(url)
    #endif
}

/// Cross-platform image type
#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif

/// Data directory: iCloud Drive if available, otherwise Application Support.
/// This allows the app to read/write directly to iCloud without needing symlinks.
var hikingDataDir: URL {
    let iCloudDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Hiking", isDirectory: true)
    if FileManager.default.fileExists(atPath: iCloudDir.path) {
        return iCloudDir
    }
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Hiking", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

/// Local config directory: always Application Support (for machine-specific files like API keys).
var hikingLocalDir: URL {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Hiking", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

/// Resource bundle that works with both SPM (Bundle.module) and Xcode (Bundle.main)
var resourceBundle: Bundle {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle.main
    #endif
}
