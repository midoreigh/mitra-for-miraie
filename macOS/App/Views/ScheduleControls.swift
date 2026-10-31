import SwiftUI
import MitraKit

/// The timer popover: when the AC should turn itself off and on. Both live in the AC, so they
/// work with the Mac asleep. Changes go to the AC a moment after the last edit.
struct TimerPopover: View {
    @Environment(ACStore.self) private var store
    @State private var off: Date?
    @State private var on: Date?

    init(state: ACState) {
        _off = State(initialValue: state.offTimer)
        _on = State(initialValue: state.onTimer)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Timer").font(.headline)
            TimerRow(title: "Turn off", date: $off, suggested: { Date().addingTimeInterval(3600) },
                     quickPicks: [30, 60, 120, 240])
            Divider()
            TimerRow(title: "Turn on", date: $on, suggested: { TimerRow.next(hour: 7, minute: 0) }, quickPicks: [])
            Text("Your AC keeps its timers itself, so they work even while your Mac is asleep.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 300)
        .task(id: [off, on]) {
            let state = store.state
            guard !Self.same(off, state.offTimer) || !Self.same(on, state.onTimer) else { return }
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            store.send(.timers(off: off.map(TimerRow.upcoming), on: on.map(TimerRow.upcoming)))
        }
    }

    /// Equal to the minute, or both unset: the AC's clock can be a few seconds out.
    private static func same(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (a?, b?): abs(a.timeIntervalSince(b)) < 60
        default: false
        }
    }
}

private struct TimerRow: View {
    let title: String
    @Binding var date: Date?
    let suggested: () -> Date
    /// Minutes from now.
    let quickPicks: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(title, isOn: Binding(get: { date != nil },
                                            set: { date = $0 ? Self.toMinute(suggested()) : nil }))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Spacer()
                DatePicker(title, selection: Binding(get: { date ?? Self.toMinute(suggested()) },
                                                     set: { date = Self.upcoming($0) }),
                           displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .disabled(date == nil)
            }
            if let date {
                Text(Self.relative(to: date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !quickPicks.isEmpty {
                HStack(spacing: 6) {
                    ForEach(quickPicks, id: \.self) { minutes in
                        Button(minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h") {
                            date = Self.toMinute(Date().addingTimeInterval(Double(minutes) * 60))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    /// "In 3 h 50 min, at 9:20 PM" or "Tomorrow at 7:00 AM".
    private static func relative(to date: Date) -> String {
        let minutes = Int((date.timeIntervalSinceNow / 60).rounded())
        let time = date.formatted(date: .omitted, time: .shortened)
        guard minutes < 12 * 60 || Calendar.current.isDateInToday(date) else {
            return Calendar.current.isDateInTomorrow(date) ? "Tomorrow at \(time)" : time
        }
        let hours = minutes / 60, rest = minutes % 60
        let span = hours == 0 ? "\(rest) min" : rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
        return "In \(span), at \(time)"
    }

    static func toMinute(_ date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded() * 60)
    }

    /// The next time it's this time of day: today if that's still ahead, otherwise tomorrow.
    static func upcoming(_ date: Date) -> Date {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return next(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    static func next(hour: Int, minute: Int) -> Date {
        let now = Date()
        let today = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        return today > now.addingTimeInterval(30) ? today : today.addingTimeInterval(24 * 3600)
    }
}

/// The sleep popover: start or stop a profile. Profiles are made in Settings.
struct SleepPopover: View {
    @Environment(ACStore.self) private var store

    var body: some View {
        let state = store.state
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep").font(.headline)
            VStack(spacing: 2) {
                ForEach(store.allSleepProfiles) { profile in
                    row(profile, state: state)
                }
                if let id = state.sleepProfile, store.runningSleepProfile == nil {
                    // Started from the MirAIe app: Mitra doesn't know its name or hours.
                    row(SleepProfile(id: id, name: "Sleep profile", temperatures: [], turnsOffAtEnd: false),
                        state: state)
                }
            }
            if !state.isOn {
                Text("Turn your AC on to start a profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            Button("Edit profiles…") { StatusMenu.shared.showSettings() }
                .buttonStyle(.link)
        }
        .padding(16)
        .frame(width: 300)
    }

    private func row(_ profile: SleepProfile, state: ACState) -> some View {
        let running = state.sleepProfile == profile.id
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.body.weight(.medium))
                Text(running ? SleepProfile.progress(profile, hour: state.sleepHour) : profile.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if running {
                Button("Stop") { store.stopSleep() }
                    .controlSize(.small)
            } else {
                Button("Start") { store.send(.startSleep(profile)) }
                    .controlSize(.small)
                    .disabled(!state.isOn)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(running ? 0.15 : 0)))
    }
}

extension SleepProfile {
    /// "26° 27° 27°, then off", or how Gentle works.
    var summary: String {
        if isGentle { return "Your temperature, then 1° and 2° warmer, over 8 h, then off" }
        let temperatures = temperatures.map { "\(Int($0))°" }.joined(separator: " ")
        return turnsOffAtEnd ? "\(temperatures), then off" : temperatures
    }

    /// "Hour 2 of 3". For a profile started in the MirAIe app, which hour means little without
    /// its length, so just where it came from.
    static func progress(_ profile: SleepProfile, hour: Int?) -> String {
        if profile.temperatures.isEmpty { return "Started in the MirAIe app" }
        guard let hour else { return "Running" }
        return "Hour \(min(hour + 1, profile.temperatures.count)) of \(profile.temperatures.count)"
    }
}
