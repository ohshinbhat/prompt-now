import Foundation

public enum NudgeCopy {
    public static let lines = [
        "Review, refine, reprompt.",
        "Tiny loop, big polish.",
        "Changes want eyeballs.",
        "One more prompt might do it.",
        "Your future self left a tab open."
    ]

    public static func line(for index: Int) -> String {
        lines[abs(index) % lines.count]
    }
}
