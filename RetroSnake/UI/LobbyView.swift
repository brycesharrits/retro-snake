import SwiftUI

struct LobbyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session = LobbySession()

    private let magenta = Color(red: 1.0, green: 0.35, blue: 0.75)
    private let acidGreen = Color(red: 0.35, green: 1.0, blue: 0.5)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.05),
                    Color(red: 0.05, green: 0.02, blue: 0.10),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("BATTLE\nROYALE")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(magenta)
                    .shadow(color: magenta, radius: 12)

                nameField
                    .disabled(session.isConnected)
                    .opacity(session.isConnected ? 0.55 : 1)

                if !session.isConnected {
                    hostJoinButtons
                } else {
                    connectedBody
                }

                Spacer()

                NeonButton(title: "BACK", color: .white.opacity(0.85)) {
                    session.stop()
                    dismiss()
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)

            CRTOverlay()
        }
        .fullScreenCover(item: $session.matchStart) { info in
            GameView(
                mode: .battleRoyale,
                transport: info.transport,
                initialSnapshot: info.snapshot,
                remotePeers: info.remotePeers
            )
        }
    }

    private var nameField: some View {
        VStack(spacing: 6) {
            Text("NAME")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            TextField("Player", text: $session.displayName)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.cyan.opacity(0.5), lineWidth: 1)
                )
        }
        .frame(maxWidth: 240)
    }

    private var hostJoinButtons: some View {
        HStack(spacing: 12) {
            NeonButton(title: "HOST", color: .cyan) { session.host() }
            NeonButton(title: "JOIN", color: magenta) { session.join() }
        }
    }

    @ViewBuilder
    private var connectedBody: some View {
        VStack(spacing: 10) {
            Text(session.role == .host ? "HOSTING" : "JOINED")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))

            if session.connectedPeers.isEmpty {
                Text(session.role == .host
                     ? "waiting for players..."
                     : "waiting for host...")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                VStack(spacing: 4) {
                    ForEach(session.connectedPeers, id: \.value) { p in
                        Text("• \(displayNameFrom(p))")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
        }

        if session.role == .host {
            let canStart = !session.connectedPeers.isEmpty
            NeonButton(
                title: "START",
                color: canStart ? acidGreen : .white.opacity(0.25)
            ) {
                if canStart { session.startMatch() }
            }
        }
    }

    /// Strip the "#abcd" uniqueness suffix for display.
    private func displayNameFrom(_ p: PeerID) -> String {
        p.value.split(separator: "#").first.map(String.init) ?? p.value
    }
}

#Preview {
    LobbyView()
}
