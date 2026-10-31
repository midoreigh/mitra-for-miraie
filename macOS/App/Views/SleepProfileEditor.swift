import SwiftUI
import MitraKit

/// Settings' list of the user's sleep profiles.
struct SleepProfilesSection: View {
    @Environment(ACStore.self) private var store
    @State private var editing: SleepProfile?

    var body: some View {
        Section {
            ForEach(store.sleepProfiles) { profile in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                        Text(profile.summary).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit") { editing = profile }
                }
            }
            Button("New Profile…") { editing = .new() }
        } header: {
            Text("Sleep profiles")
        } footer: {
            Text("Set a temperature for each hour of the night, then start the profile with the bed button in the panel. Your AC runs it by itself. Gentle is built into the AC and works from whatever temperature it's set to.")
        }
        .sheet(item: $editing) { profile in
            SleepProfileEditor(profile: profile, isNew: !store.sleepProfiles.contains { $0.id == profile.id },
                               save: { store.save($0) }, delete: { store.deleteSleepProfile(id: profile.id) })
        }
    }
}

/// Edits one profile: its name, a bar for each hour (drag to set the temperature) and whether
/// the AC turns off at the end.
struct SleepProfileEditor: View {
    @State var profile: SleepProfile
    let isNew: Bool
    let save: (SleepProfile) -> Void
    let delete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TextField("Name", text: $profile.name)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
            HourBars(temperatures: $profile.temperatures)
            Text("Drag a bar to set that hour's temperature. Right-click a bar to remove it.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Turn the AC off when the profile ends", isOn: $profile.turnsOffAtEnd)
            HStack {
                if !isNew {
                    Button("Delete", role: .destructive) {
                        delete()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save(profile)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(profile.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

private struct HourBars: View {
    @Binding var temperatures: [Double]
    private let range = ACState.temperatureRange
    private let height = 180.0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(temperatures.indices, id: \.self) { index in
                VStack(spacing: 6) {
                    bar(index)
                    Text("\(index + 1) h").font(.caption).foregroundStyle(.secondary)
                }
            }
            if temperatures.count < SleepProfile.hours.upperBound {
                VStack(spacing: 6) {
                    Button {
                        temperatures.append(temperatures.last ?? 26)
                    } label: {
                        Image(systemName: "plus")
                            .frame(maxWidth: .infinity, maxHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .background(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.5)))
                    .help("Add an hour")
                    Text("\(temperatures.count + 1) h").font(.caption).foregroundStyle(.tertiary)
                }
                .frame(width: 44)
            }
            Spacer(minLength: 0)
        }
        .frame(height: height + 24, alignment: .bottom)
    }

    private func bar(_ index: Int) -> some View {
        let value = temperatures[index]
        let share = 0.12 + 0.88 * (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return ZStack(alignment: .bottom) {
            Color.clear
            UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 4, bottomTrailingRadius: 4,
                                   topTrailingRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.36, blue: 0.86), Color(red: 0.55, green: 0.75, blue: 1.0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: height * share)
                .overlay(alignment: .top) {
                    Text("\(Int(value))°")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 6)
                }
        }
        .frame(width: 44, height: height)
        .contentShape(.rect)
        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
            let share = 1 - min(1, max(0, drag.location.y / height))
            let degrees = range.lowerBound + ((share - 0.12) / 0.88 * (range.upperBound - range.lowerBound))
            temperatures[index] = min(range.upperBound, max(range.lowerBound, degrees.rounded()))
        })
        .contextMenu {
            if temperatures.count > 1 {
                Button("Remove Hour \(index + 1)") { temperatures.remove(at: index) }
            }
        }
        .animation(.snappy(duration: 0.15), value: value)
    }
}
