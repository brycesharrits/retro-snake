import SwiftUI

struct LobbyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.05),
                    Color(red: 0.05, green: 0.02, blue: 0.10),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Text("BATTLE\nROYALE")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.75))
                    .shadow(color: Color(red: 1.0, green: 0.35, blue: 0.75), radius: 12)

                Text("LOBBY — COMING SOON")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                NeonButton(title: "BACK", color: .white.opacity(0.85)) {
                    dismiss()
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)

            CRTOverlay()
        }
    }
}

#Preview {
    LobbyView()
}
