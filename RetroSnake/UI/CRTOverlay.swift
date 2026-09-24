import SwiftUI

/// Cheap CRT overlay: horizontal scanlines + soft vignette. Sits above the
/// board with `.allowsHitTesting(false)` so it never eats gestures.
struct CRTOverlay: View {
    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let lineHeight: CGFloat = 3
                var y: CGFloat = 0
                let lineColor = Color.black.opacity(0.28)
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    ctx.fill(Path(rect), with: .color(lineColor))
                    y += lineHeight
                }
            }
            .blendMode(.multiply)

            // Vignette
            RadialGradient(
                colors: [.clear, .black.opacity(0.75)],
                center: .center,
                startRadius: 0,
                endRadius: 600
            )
            .blendMode(.multiply)
        }
        .allowsHitTesting(false)
    }
}
