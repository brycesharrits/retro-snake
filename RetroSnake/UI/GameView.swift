import SwiftUI

struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var game = GameState()
    @State private var dragStart: CGPoint?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                HUDView(game: game, onQuit: {
                    game.stop()
                    dismiss()
                })
                .padding(.horizontal, 16)
                .padding(.top, 4)

                ZStack {
                    BoardView(game: game)
                    CRTOverlay()

                    if game.isGameOver {
                        GameOverView(
                            score: game.snakes.first(where: { $0.isPlayer })?.score ?? 0,
                            botsAlive: game.aliveBotCount,
                            onRestart: {
                                game.newGame()
                                game.start()
                            },
                            onQuit: {
                                game.stop()
                                dismiss()
                            }
                        )
                    }
                }
                .contentShape(Rectangle())
                .gesture(swipeGesture)
            }
        }
        .onAppear {
            game.newGame()
            game.start()
        }
        .onDisappear { game.stop() }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if dragStart == nil { dragStart = value.startLocation }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                dragStart = nil
                if abs(dx) < 12 && abs(dy) < 12 { return }
                let dir: Direction = abs(dx) > abs(dy)
                    ? (dx > 0 ? .right : .left)
                    : (dy > 0 ? .down : .up)
                game.requestPlayerDirection(dir)
            }
    }
}

private struct HUDView: View {
    let game: GameState
    let onQuit: () -> Void

    var body: some View {
        HStack {
            Text("SCORE  \(game.snakes.first(where: { $0.isPlayer })?.score ?? 0)")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(.cyan)
                .shadow(color: .cyan.opacity(0.8), radius: 4)

            Spacer()

            Text("BOTS  \(game.aliveBotCount)")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.75))
                .shadow(color: Color(red: 1.0, green: 0.35, blue: 0.75).opacity(0.7), radius: 4)

            Spacer()

            Button(action: onQuit) {
                Text("QUIT")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.white.opacity(0.4), lineWidth: 1)
                    )
            }
        }
    }
}

private struct GameOverView: View {
    let score: Int
    let botsAlive: Int
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.25, blue: 0.4))
                    .shadow(color: Color(red: 1.0, green: 0.25, blue: 0.4), radius: 10)

                VStack(spacing: 6) {
                    Text("SCORE  \(score)")
                    Text("BOTS LEFT  \(botsAlive)")
                }
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)
                .shadow(color: .cyan.opacity(0.6), radius: 4)

                HStack(spacing: 12) {
                    NeonButton(title: "RETRY", color: .cyan, action: onRestart)
                    NeonButton(title: "QUIT", color: .white.opacity(0.8), action: onQuit)
                }
            }
            .padding(28)
        }
        .transition(.opacity)
    }
}

struct NeonButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color, lineWidth: 1.5)
                        .shadow(color: color.opacity(0.9), radius: 6)
                )
        }
    }
}
