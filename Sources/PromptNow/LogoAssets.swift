import AppKit

enum LogoAssets {
    static var mark: NSImage? {
        NSImage(named: "PromptNowMark") ?? imageFromBundle(named: "PromptNowMark", extension: "png")
    }

    private static func imageFromBundle(named name: String, extension ext: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
