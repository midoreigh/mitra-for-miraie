import SwiftUI
import MitraKit
import MitraUI

struct SignInView: View {
    @Environment(ACStore.self) private var store
    @State private var username = ""
    @State private var password = ""
    @State private var isWorking = false
    /// Set once the user leaves the username field, so we don't nag while they type.
    @State private var usernameTouched = false
    @State private var capsLockOn = NSEvent.modifierFlags.contains(.capsLock)
    @State private var capsLockMonitor: Any?
    @State private var shakes = 0
    @FocusState private var focus: Field?

    private enum Field { case username, password }

    init(username: String = "", usernameTouched: Bool = false) {
        _username = State(initialValue: username)
        _usernameTouched = State(initialValue: usernameTouched)
    }

    /// How a field is doing, which colours its outline and message.
    private enum Validity { case neutral, valid, warning, error }

    /// A running AC sweeping both ways, to greet the user.
    private static let demoState: ACState = {
        var state = ACState()
        state.isOn = true
        return state
    }()

    private var identifier: MirAIeAPI.LoginIdentifier? { MirAIeAPI.loginIdentifier(for: username) }
    private var canSubmit: Bool { identifier != nil && !password.isEmpty && !isWorking }

    private var errorMessage: String? {
        if case .failed(let message) = store.phase { message } else { nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ACUnitView(state: Self.demoState)
                .frame(height: 92)
                .padding(.horizontal, 24)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.6), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))

            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Mitra for MirAIe")
                    .font(.title2.weight(.semibold))
                Text("Use the same login as the MirAIe app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                let user = usernameStatus
                field("Mobile number or email", .username, validity: user.validity, message: user.message) {
                    TextField("98765 43210", text: $username)
                        .textContentType(.username)
                        .focused($focus, equals: .username)
                        .onSubmit {
                            usernameTouched = true
                            if identifier != nil { focus = .password }
                        }
                }
                let pass = passwordStatus
                field("Password", .password, validity: pass.validity, message: pass.message) {
                    SecureField("MirAIe password", text: $password)
                        .textContentType(.password)
                        .focused($focus, equals: .password)
                        .onSubmit(submit)
                }
            }
            .modifier(Shake(animatableData: CGFloat(shakes)))

            if let errorMessage {
                ErrorBanner(message: errorMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Label("Your password stays in your Mac's Keychain and is only sent to MirAIe.",
                  systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.glass)
                Spacer()
                Button(action: submit) {
                    if isWorking {
                        ProgressView().controlSize(.small).frame(width: 64)
                    } else {
                        Text("Sign In").frame(width: 64)
                    }
                }
                .buttonStyle(.glassProminent)
                .tint(ACMode.cool.tint)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
            }
            .controlSize(.large)
        }
        .padding(20)
        .animation(.snappy, value: errorMessage)
        .onAppear {
            if username.isEmpty { username = store.lastUsername }
            focus = username.isEmpty ? .username : .password
            capsLockMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                capsLockOn = event.modifierFlags.contains(.capsLock)
                return event
            }
        }
        .onDisappear {
            capsLockMonitor.map(NSEvent.removeMonitor)
            capsLockMonitor = nil
        }
        .onChange(of: focus) { old, _ in
            if old == .username, !username.isEmpty { usernameTouched = true }
        }
        .onChange(of: username) { old, new in
            // Refilling the last username on reopen isn't an edit; keep its error showing.
            if !(old.isEmpty && new == store.lastUsername) { store.clearError() }
        }
        .onChange(of: password) { store.clearError() }
        .onChange(of: errorMessage) { _, message in
            guard message != nil else { return }
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
            focus = .password
        }
    }

    // MARK: - Validation

    /// What we understood from the username, or what's wrong with it.
    private var usernameStatus: (validity: Validity, message: Text) {
        if errorMessage != nil, identifier != nil {
            return (.error, Text("Check that this matches your MirAIe account."))
        }
        switch identifier {
        case .mobile(let number):
            return (.valid, Text("\(Image(systemName: "phone.fill")) Signing in as \(Self.format(mobile: number))"))
        case .email(let address):
            return (.valid, Text("\(Image(systemName: "envelope.fill")) Signing in as \(address)"))
        case nil where usernameTouched && !username.trimmingCharacters(in: .whitespaces).isEmpty:
            return (.warning, Text("\(Image(systemName: "exclamationmark.circle.fill")) \(Self.problem(with: username))"))
        case nil:
            return (.neutral, Text("Indian numbers don't need +91. Elsewhere, start with your country code, e.g. +44."))
        }
    }

    private var passwordStatus: (validity: Validity, message: Text?) {
        if errorMessage != nil { return (.error, nil) }
        if capsLockOn, focus == .password {
            return (.warning, Text("\(Image(systemName: "capslock.fill")) Caps Lock is on"))
        }
        return (.neutral, nil)
    }

    private static func problem(with username: String) -> String {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        if trimmed.contains("@") { return "That email address looks incomplete." }
        let digits = trimmed.filter(\.isNumber)
        if trimmed.contains(where: { $0.isLetter }) { return "Enter a mobile number or a full email address." }
        if trimmed.hasPrefix("+") { return "Include the country code and number, e.g. +44 7700 900123." }
        if digits.count < 10 { return "Mobile numbers have 10 digits; this has \(digits.count)." }
        return "That's too many digits for an Indian number. Start with + for other countries."
    }

    /// "+919876543210" → "+91 98765 43210".
    private static func format(mobile: String) -> String {
        guard mobile.hasPrefix("+91"), mobile.count == 13 else { return mobile }
        let digits = mobile.dropFirst(3)
        return "+91 \(digits.prefix(5)) \(digits.suffix(5))"
    }

    // MARK: - Pieces

    private func field<Input: View>(_ title: String, _ name: Field, validity: Validity, message: Text?,
                                    @ViewBuilder input: () -> Input) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        let tint: Color? = switch validity {
        case .error: .red
        case .warning: .orange
        case .valid, .neutral: focus == name ? ACMode.cool.tint : nil
        }
        let messageColor: Color = switch validity {
        case .valid: .green
        case .warning: .orange
        case .error: .red
        case .neutral: .secondary
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.callout.weight(.medium))
            input()
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(shape.fill(Color.primary.opacity(0.07)))
                .overlay(shape.strokeBorder(tint ?? Color.primary.opacity(0.16), lineWidth: tint == nil ? 1 : 2))
                .overlay(alignment: .trailing) {
                    if validity == .valid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .padding(.trailing, 10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            if let message {
                message
                    .font(.caption)
                    .foregroundStyle(messageColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: validity)
        .animation(.easeOut(duration: 0.15), value: focus)
    }

    private func submit() {
        usernameTouched = true
        guard canSubmit else { return }
        isWorking = true
        Task {
            await store.signIn(username: username, password: password)
            isWorking = false
        }
    }
}

/// Why sign-in failed, in a red callout.
private struct ErrorBanner: View {
    let message: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.octagon.fill")
            Text(message).fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
        .foregroundStyle(.red)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(.red.opacity(0.12)))
        .overlay(shape.strokeBorder(.red.opacity(0.35)))
    }
}

/// A quick side-to-side shake, played when sign-in fails.
private struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(animatableData * .pi * 4), y: 0))
    }
}

#Preview("Empty") { SignInView().environment(ACStore()) }
#Preview("Valid mobile") { SignInView(username: "98765 43210").environment(ACStore()) }
#Preview("Too short") { SignInView(username: "98765", usernameTouched: true).environment(ACStore()) }
