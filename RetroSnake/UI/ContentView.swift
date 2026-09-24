import SwiftUI

struct ContentView: View {
    @State private var showGame = false
    @State private var titlePulse = false

    var body: some View {
        ZStack {
            // Deep-space background
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.05),
                    Color(red: 0.05, green: 0.02, blue: 0.10),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 8) {
                    Text("RETRO")
                        .font(.system(size: 64, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .shadow(color: .cyan, radius: titlePulse ? 18 : 10)

                    Text("SNAKE")
                        .font(.system(size: 64, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.75))
                        .shadow(color: Color(red: 1.0, green: 0.35, blue: 0.75),
                                radius: titlePulse ? 18 : 10)
                }
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                           value: titlePulse)

                Text("v s. 3 bots")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                NeonButton(title: "PLAY", color: .cyan) {
                    showGame = true
                }

                Text("swipe to steer")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)

            CRTOverlay()
        }
        .onAppear { titlePulse = true }
        .fullScreenCover(isPresented: $showGame) {
            GameView()
        }
    }
}

#Preview {
    ContentView()
}
