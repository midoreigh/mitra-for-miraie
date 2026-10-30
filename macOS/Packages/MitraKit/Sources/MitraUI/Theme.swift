import SwiftUI
import MitraKit

public extension ACMode {
    /// The colour of the air in this mode.
    var tint: Color {
        switch self {
        case .cool: Color(red: 0.33, green: 0.68, blue: 1.00)
        case .auto: Color(red: 0.62, green: 0.55, blue: 1.00)
        case .dry: Color(red: 0.22, green: 0.83, blue: 0.76)
        case .fan: Color(red: 0.78, green: 0.84, blue: 0.93)
        case .heat: Color(red: 1.00, green: 0.55, blue: 0.24)
        }
    }

    /// A lighter companion to `tint`, for gradients.
    var glow: Color {
        switch self {
        case .cool: Color(red: 0.49, green: 0.89, blue: 1.00)
        case .auto: Color(red: 0.86, green: 0.62, blue: 1.00)
        case .dry: Color(red: 0.55, green: 0.95, blue: 0.80)
        case .fan: Color(red: 0.95, green: 0.97, blue: 1.00)
        case .heat: Color(red: 1.00, green: 0.78, blue: 0.42)
        }
    }

    /// A deeper shade for controls showing this mode, so white text and icons read clearly on
    /// it. (`tint` is the air's colour, too light for that in Dry and Fan.)
    var controlTint: Color {
        switch self {
        case .cool: Color(red: 0.12, green: 0.42, blue: 0.9)
        case .auto: Color(red: 0.42, green: 0.32, blue: 0.85)
        case .dry: Color(red: 0.0, green: 0.48, blue: 0.44)
        case .fan: Color(red: 0.33, green: 0.4, blue: 0.52)
        case .heat: Color(red: 0.82, green: 0.36, blue: 0.08)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [tint, glow], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

public extension Color {
    /// The AC's display: its digits on the unit, and the Display control that switches them.
    static let acDisplay = Color(red: 0.1, green: 0.45, blue: 0.95)
}

public extension ACState {
    /// What the AC is doing, in a few words, e.g. "Cooling to 24°".
    var summary: String {
        guard isOnline else { return "Offline" }
        guard isOn else { return "Off" }
        let target = Self.format(setpoint)
        return switch mode {
        case .cool: "Cooling to \(target)"
        case .heat: "Heating to \(target)"
        case .dry: "Drying at \(target)"
        case .fan: "Fan only"
        case .auto: "Auto at \(target)"
        }
    }

    /// What the AC is doing, without the temperature, e.g. "Cooling".
    var activity: String {
        guard isOnline else { return "Offline" }
        guard isOn else { return "Off" }
        return switch mode {
        case .cool: "Cooling"
        case .heat: "Heating"
        case .dry: "Drying"
        case .fan: "Fan only"
        case .auto: "Auto"
        }
    }

    static func format(_ temperature: Double) -> String {
        temperature == temperature.rounded()
            ? "\(Int(temperature))°" : String(format: "%.1f°", temperature)
    }

    var roomTemperatureText: String? {
        roomTemperature.map { String(format: "%.1f°", $0) }
    }
}

/// Names for louver positions.
public enum LouverLabel {
    public static func vertical(_ position: Int) -> String {
        switch position {
        case Louver.swing: "Swing"
        case 1: "Highest"
        case 2: "High"
        case 3: "Middle"
        case 4: "Low"
        default: "Lowest"
        }
    }

    public static func horizontal(_ position: Int) -> String {
        guard position != Louver.swing else { return "Swing" }
        return switch Louver.horizontalSlot(position) {
        case 1: "Far left"
        case 2: "Left"
        case 3: "Centre"
        case 4: "Right"
        default: "Far right"
        }
    }
}
