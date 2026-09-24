import SwiftUI

/// The neon board: renders the grid, food, and snakes with an additive bloom
/// pass. Uses `TimelineView` at ~60fps so the pulse animations stay smooth
/// independent of the game tick.
struct BoardView: View {
    let game: GameState

    var body: some View {
        GeometryReader { geo in
            let cell = min(geo.size.width / CGFloat(game.width),
                           geo.size.height / CGFloat(game.height))
            let boardW = cell * CGFloat(game.width)
            let boardH = cell * CGFloat(game.height)

            ZStack {
                // Faint grid + backdrop
                Canvas { ctx, _ in
                    drawBackdrop(ctx: ctx, cell: cell)
                }

                // Bloom layers: draw the scene twice more, blurred + additive.
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    bloomStack(time: timeline.date.timeIntervalSinceReferenceDate,
                               cell: cell)
                }
            }
            .frame(width: boardW, height: boardH)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Drawing

    @ViewBuilder
    private func bloomStack(time: TimeInterval, cell: CGFloat) -> some View {
        ZStack {
            Canvas { ctx, _ in
                drawScene(ctx: ctx, cell: cell, time: time, glow: false)
            }
            Canvas { ctx, _ in
                drawScene(ctx: ctx, cell: cell, time: time, glow: true)
            }
            .blur(radius: cell * 0.9)
            .blendMode(.plusLighter)
            .opacity(0.9)

            Canvas { ctx, _ in
                drawScene(ctx: ctx, cell: cell, time: time, glow: true)
            }
            .blur(radius: cell * 2.2)
            .blendMode(.plusLighter)
            .opacity(0.55)
        }
    }

    private func drawBackdrop(ctx: GraphicsContext, cell: CGFloat) {
        let w = cell * CGFloat(game.width)
        let h = cell * CGFloat(game.height)

        // Board background
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                 with: .color(Color(red: 0.02, green: 0.03, blue: 0.06)))

        // Faint grid lines
        var grid = Path()
        for x in 0...game.width {
            let px = CGFloat(x) * cell
            grid.move(to: CGPoint(x: px, y: 0))
            grid.addLine(to: CGPoint(x: px, y: h))
        }
        for y in 0...game.height {
            let py = CGFloat(y) * cell
            grid.move(to: CGPoint(x: 0, y: py))
            grid.addLine(to: CGPoint(x: w, y: py))
        }
        ctx.stroke(grid,
                   with: .color(Color(red: 0.1, green: 0.4, blue: 0.6).opacity(0.12)),
                   lineWidth: 0.5)

        // Border
        ctx.stroke(Path(CGRect(x: 0.5, y: 0.5, width: w - 1, height: h - 1)),
                   with: .color(Color.cyan.opacity(0.35)),
                   lineWidth: 1)
    }

    private func drawScene(ctx: GraphicsContext, cell: CGFloat, time: TimeInterval, glow: Bool) {
        // Food — pulsing dot
        let pulse = 0.5 + 0.5 * sin(time * 4)
        for f in game.food {
            let rect = cellRect(f, cell: cell).insetBy(dx: cell * 0.18, dy: cell * 0.18)
            let color = Color(red: 1.0, green: 0.35 + 0.25 * pulse, blue: 0.1)
            ctx.fill(Path(ellipseIn: rect),
                     with: .color(color.opacity(glow ? 0.95 : 1.0)))
        }

        // Snakes
        for snake in game.snakes {
            let base = snake.alive ? snake.color : snake.color.opacity(0.35)
            let inset = cell * (snake.isPlayer ? 0.10 : 0.14)
            for (i, seg) in snake.body.enumerated() {
                let r = cellRect(seg, cell: cell).insetBy(dx: inset, dy: inset)
                let corner = cell * 0.28
                let path = Path(roundedRect: r, cornerRadius: corner)

                if i == 0 {
                    // Head — brighter fill + outline
                    ctx.fill(path, with: .color(base))
                    if !glow {
                        ctx.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 1)
                    }
                } else {
                    // Body — slightly translucent for a segmented feel
                    let fade = max(0.35, 1.0 - Double(i) * 0.015)
                    ctx.fill(path, with: .color(base.opacity(fade)))
                }
            }
        }
    }

    private func cellRect(_ p: GridPoint, cell: CGFloat) -> CGRect {
        CGRect(x: CGFloat(p.x) * cell, y: CGFloat(p.y) * cell,
               width: cell, height: cell)
    }
}
