import AppIntents
import MitraKit

/// An air conditioner, as Siri, Shortcuts and widget configuration see it.
struct ACEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Air Conditioner"
    static let defaultQuery = ACQuery()

    let id: String
    let name: String
    let room: String?

    init(_ device: Device) {
        id = device.id
        name = device.name
        room = device.room
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: room.map { "\($0)" },
                              image: .init(systemName: "air.conditioner.horizontal"))
    }
}

struct ACQuery: EntityQuery {
    func entities(for identifiers: [ACEntity.ID]) async throws -> [ACEntity] {
        SharedStore.shared.devices.filter { identifiers.contains($0.id) }.map(ACEntity.init)
    }

    func suggestedEntities() async throws -> [ACEntity] {
        SharedStore.shared.devices.map(ACEntity.init)
    }

    func defaultResult() async -> ACEntity? {
        SharedStore.shared.selectedDevice.map(ACEntity.init)
    }
}

// MARK: - Settings as Siri understands them

enum ACModeOption: String, AppEnum {
    case cool, auto, dry, fan, heat

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Mode"
    static let caseDisplayRepresentations: [ACModeOption: DisplayRepresentation] = [
        .cool: DisplayRepresentation(title: "Cool", image: .init(systemName: "snowflake")),
        .auto: DisplayRepresentation(title: "Auto", image: .init(systemName: "sparkles")),
        .dry: DisplayRepresentation(title: "Dry", image: .init(systemName: "drop.fill"), synonyms: ["Dehumidify"]),
        .fan: DisplayRepresentation(title: "Fan", image: .init(systemName: "fan.fill"), synonyms: ["Fan only"]),
        .heat: DisplayRepresentation(title: "Heat", image: .init(systemName: "sun.max.fill"), synonyms: ["Warm"]),
    ]

    var mode: ACMode { ACMode(rawValue: rawValue)! }
}

enum FanSpeedOption: String, AppEnum {
    case auto, quiet, low, medium, high

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Fan Speed"
    static let caseDisplayRepresentations: [FanSpeedOption: DisplayRepresentation] = [
        .auto: "Auto", .quiet: "Quiet", .low: "Low", .medium: "Medium", .high: "High",
    ]

    var speed: FanSpeed { FanSpeed(rawValue: rawValue)! }
}

enum VerticalAirflowOption: Int, AppEnum {
    case swing = 0, highest, high, middle, low, lowest

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Up/Down Airflow"
    static let caseDisplayRepresentations: [VerticalAirflowOption: DisplayRepresentation] = [
        .swing: DisplayRepresentation(title: "Swing", synonyms: ["Auto"]),
        .highest: DisplayRepresentation(title: "Highest", synonyms: ["Up", "Straight"]),
        .high: "High",
        .middle: DisplayRepresentation(title: "Middle", synonyms: ["Centre", "Center"]),
        .low: "Low",
        .lowest: DisplayRepresentation(title: "Lowest", synonyms: ["Down"]),
    ]
}

/// Raw values run from the left; `Louver.horizontalLeftToRight` turns them into MirAIe's numbers.
enum HorizontalAirflowOption: Int, AppEnum {
    case swing = 0, farLeft, left, centre, right, farRight

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Left/Right Airflow"
    static let caseDisplayRepresentations: [HorizontalAirflowOption: DisplayRepresentation] = [
        .swing: DisplayRepresentation(title: "Swing", synonyms: ["Auto"]),
        .farLeft: "Far Left",
        .left: "Left",
        .centre: DisplayRepresentation(title: "Centre", synonyms: ["Center", "Straight"]),
        .right: "Right",
        .farRight: "Far Right",
    ]
}

enum TemperatureDirection: String, AppEnum {
    case cooler, warmer

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Direction"
    static let caseDisplayRepresentations: [TemperatureDirection: DisplayRepresentation] = [
        .cooler: DisplayRepresentation(title: "Cooler", synonyms: ["Colder"]),
        .warmer: DisplayRepresentation(title: "Warmer", synonyms: ["Hotter"]),
    ]
}
