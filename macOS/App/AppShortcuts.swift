import AppIntents

/// Phrases Siri recognises without any setup. Each must mention the app's name.
struct MitraShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TurnOnACIntent(), phrases: [
            "Turn on the AC with \(.applicationName)",
            "Turn on the AC in \(.applicationName)",
            "\(.applicationName) AC on",
            "Turn on \(\.$device) with \(.applicationName)",
        ], shortTitle: "Turn On", systemImageName: "power")

        AppShortcut(intent: TurnOffACIntent(), phrases: [
            "Turn off the AC with \(.applicationName)",
            "Turn off the AC in \(.applicationName)",
            "\(.applicationName) AC off",
            "Turn off \(\.$device) with \(.applicationName)",
        ], shortTitle: "Turn Off", systemImageName: "power.dotted")

        AppShortcut(intent: SetACTemperatureIntent(), phrases: [
            "Set the \(.applicationName) temperature",
            "Set the AC temperature with \(.applicationName)",
            "Change the temperature in \(.applicationName)",
        ], shortTitle: "Set Temperature", systemImageName: "thermometer.medium")

        AppShortcut(intent: AdjustACTemperatureIntent(), phrases: [
            "Make it \(\.$direction) with \(.applicationName)",
            "Make the AC \(\.$direction) with \(.applicationName)",
            "\(.applicationName) \(\.$direction)",
        ], shortTitle: "Cooler or Warmer", systemImageName: "plusminus")

        AppShortcut(intent: SetACModeIntent(), phrases: [
            "Switch \(.applicationName) to \(\.$mode)",
            "Set the AC to \(\.$mode) with \(.applicationName)",
            "\(.applicationName) \(\.$mode) mode",
        ], shortTitle: "Set Mode", systemImageName: "snowflake")

        AppShortcut(intent: SetACFanSpeedIntent(), phrases: [
            "Set the \(.applicationName) fan to \(\.$speed)",
            "\(.applicationName) fan \(\.$speed)",
        ], shortTitle: "Fan Speed", systemImageName: "fan")

        AppShortcut(intent: SetACVerticalAirflowIntent(), phrases: [
            "Set \(.applicationName) up down airflow to \(\.$direction)",
            "\(.applicationName) vertical swing \(\.$direction)",
        ], shortTitle: "Up/Down Airflow", systemImageName: "arrow.up.and.down")

        AppShortcut(intent: SetACHorizontalAirflowIntent(), phrases: [
            "Set \(.applicationName) left right airflow to \(\.$direction)",
            "\(.applicationName) horizontal swing \(\.$direction)",
        ], shortTitle: "Left/Right Airflow", systemImageName: "arrow.left.and.right")

        AppShortcut(intent: GetACStatusIntent(), phrases: [
            "What's the AC doing in \(.applicationName)",
            "\(.applicationName) AC status",
            "Is the AC on in \(.applicationName)",
        ], shortTitle: "Status", systemImageName: "info.circle")
    }
}
