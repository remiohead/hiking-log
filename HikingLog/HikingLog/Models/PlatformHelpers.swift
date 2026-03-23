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

/// Resource bundle that works with both SPM (Bundle.module) and Xcode (Bundle.main)
var resourceBundle: Bundle {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle.main
    #endif
}
