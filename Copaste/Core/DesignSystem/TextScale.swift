import AppKit
import Observation
import SwiftUI

/// The text size picked in Settings › Appearance, per Mac.
enum TextSize: String, CaseIterable, Identifiable {
    case small, standard, large, extraLarge

    static let storageKey = "textSize"

    var id: Self { self }

    var factor: CGFloat {
        switch self {
        case .small: 0.9
        case .standard: 1
        case .large: 1.15
        case .extraLarge: 1.3
        }
    }

    var title: String {
        switch self {
        case .small: L(.textSizeSmall)
        case .standard: L(.textSizeDefault)
        case .large: L(.textSizeLarge)
        case .extraLarge: L(.textSizeExtraLarge)
        }
    }
}

/// macOS ignores Dynamic Type, so Copaste scales its own text: views use `Font.scaled(_:)`, which reads `size` here,
/// and Observation redraws every view that did when it changes.
@Observable
final class TextScale {
    static let shared = TextScale()

    var size: TextSize {
        didSet { UserDefaults.standard.set(size.rawValue, forKey: TextSize.storageKey) }
    }

    var factor: CGFloat { size.factor }

    private init() {
        size = TextSize(rawValue: UserDefaults.standard.string(forKey: TextSize.storageKey) ?? "") ?? .standard
    }
}

extension Font {
    /// A text style at the size picked in Settings (`.caption`, `.title3`, …), in place of the fixed system style.
    static func scaled(_ style: TextStyle, design: Design = .default, weight: Weight = .regular) -> Font {
        let systemStyle = systemStyles[style] ?? .body
        let size = NSFont.preferredFont(forTextStyle: systemStyle).pointSize * TextScale.shared.factor
        return .system(size: size, weight: weight, design: design)
    }

    /// AppKit's name for each style, for its size on this Mac.
    private static let systemStyles: [TextStyle: NSFont.TextStyle] = [
        .largeTitle: .largeTitle, .title: .title1, .title2: .title2, .title3: .title3, .headline: .headline,
        .subheadline: .subheadline, .body: .body, .callout: .callout, .footnote: .footnote, .caption: .caption1, .caption2: .caption2,
    ]
}
