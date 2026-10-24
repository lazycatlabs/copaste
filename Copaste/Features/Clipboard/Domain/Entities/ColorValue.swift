import Foundation

/// A colour written as `#RGB`, `#RRGGBB`, `#RRGGBBAA`, `rgb()`/`rgba()` or `hsl()`/`hsla()`. Components are 0…1.
nonisolated struct ColorValue: Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init?(parsing text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("#") {
            self.init(hex: String(value.dropFirst()))
        } else if let match = value.wholeMatch(of: /(rgba?|hsla?)\(\s*([^)]*)\)/) {
            let parts = match.2.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" }).map(String.init)
            guard parts.count == 3 || parts.count == 4 else { return nil }
            let numbers = parts.map { Double($0.replacingOccurrences(of: "%", with: "")) }
            guard numbers.allSatisfy({ $0 != nil }) else { return nil }
            let n = numbers.compactMap { $0 }
            let alpha = n.count == 4 ? (parts[3].hasSuffix("%") ? n[3] / 100 : n[3]) : 1
            if match.1.hasPrefix("rgb") {
                guard n[0...2].allSatisfy({ (0...255).contains($0) }) else { return nil }
                self.init(red: n[0] / 255, green: n[1] / 255, blue: n[2] / 255, alpha: alpha)
            } else {
                guard (0...360).contains(n[0]), (0...100).contains(n[1]), (0...100).contains(n[2]) else { return nil }
                self.init(hue: n[0] / 360, saturation: n[1] / 100, lightness: n[2] / 100, alpha: alpha)
            }
        } else {
            return nil
        }
    }

    private init?(hex: String) {
        guard [3, 6, 8].contains(hex.count), let number = UInt64(hex, radix: 16) else { return nil }
        if hex.count == 3 {
            let r = Double((number >> 8) & 0xF), g = Double((number >> 4) & 0xF), b = Double(number & 0xF)
            self.init(red: r / 15, green: g / 15, blue: b / 15)
        } else {
            let value = hex.count == 6 ? number << 8 | 0xFF : number
            self.init(red: Double((value >> 24) & 0xFF) / 255, green: Double((value >> 16) & 0xFF) / 255,
                      blue: Double((value >> 8) & 0xFF) / 255, alpha: Double(value & 0xFF) / 255)
        }
    }

    private init(hue: Double, saturation: Double, lightness: Double, alpha: Double) {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let x = chroma * (1 - abs((hue * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = lightness - chroma / 2
        let (r, g, b): (Double, Double, Double) = switch Int(hue * 6) % 6 {
        case 0: (chroma, x, 0)
        case 1: (x, chroma, 0)
        case 2: (0, chroma, x)
        case 3: (0, x, chroma)
        case 4: (x, 0, chroma)
        default: (chroma, 0, x)
        }
        self.init(red: r + m, green: g + m, blue: b + m, alpha: alpha)
    }

    var hex: String {
        let rgb = String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
        return alpha < 1 ? rgb + String(format: "%02X", byte(alpha)) : rgb
    }

    var rgb: String {
        alpha < 1
            ? "rgba(\(byte(red)), \(byte(green)), \(byte(blue)), \(Self.trimmed(alpha)))"
            : "rgb(\(byte(red)), \(byte(green)), \(byte(blue)))"
    }

    var hsl: String {
        let maxValue = max(red, green, blue), minValue = min(red, green, blue)
        let lightness = (maxValue + minValue) / 2
        let delta = maxValue - minValue
        var hue = 0.0, saturation = 0.0
        if delta > 0 {
            saturation = delta / (1 - abs(2 * lightness - 1))
            hue = switch maxValue {
            case red: ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            case green: (blue - red) / delta + 2
            default: (red - green) / delta + 4
            }
            hue = (hue * 60 + 360).truncatingRemainder(dividingBy: 360)
        }
        let body = "\(Int(hue.rounded())), \(Int((saturation * 100).rounded()))%, \(Int((lightness * 100).rounded()))%"
        return alpha < 1 ? "hsla(\(body), \(Self.trimmed(alpha)))" : "hsl(\(body))"
    }

    private func byte(_ component: Double) -> Int { Int((min(max(component, 0), 1) * 255).rounded()) }

    private static func trimmed(_ value: Double) -> String { String(format: "%g", (value * 100).rounded() / 100) }
}
