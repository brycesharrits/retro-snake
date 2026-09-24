import Foundation

enum BotAI {
    /// Pick a direction for `snake` given the current game state.
    /// Strategy: enumerate the 3 non-reverse candidates; hard-fail on cells
    /// that would kill this tick; score survivors by (reachable open area,
    /// -distance to nearest food) with a small random tiebreak.
    static func decide(for snake: Snake, in game: GameState) -> Direction {
        let candidates = Direction.allCases.filter { $0 != snake.direction.opposite }
        let occupied = game.occupiedCells(excludingTailsWhenNotGrowing: true)

        struct Scored {
            let dir: Direction
            let area: Int
            let foodDist: Int
            let jitter: Double
        }

        var scored: [Scored] = []
        for dir in candidates {
            let next = snake.head + dir.delta
            if next.x < 0 || next.y < 0 || next.x >= game.width || next.y >= game.height { continue }
            if occupied.contains(next) { continue }

            let area = floodFillArea(from: next, game: game, blocked: occupied, cap: 60)
            let foodDist = nearestFoodDistance(from: next, foods: game.food) ?? (game.width + game.height)
            scored.append(.init(dir: dir, area: area, foodDist: foodDist, jitter: Double.random(in: 0..<0.5)))
        }

        // Nothing survives — hold direction and die honorably.
        guard !scored.isEmpty else { return snake.direction }

        // Prefer moves with plenty of room (avoid trapping), break ties by food proximity.
        let best = scored.max { a, b in
            if a.area != b.area { return a.area < b.area }
            if a.foodDist != b.foodDist { return a.foodDist > b.foodDist }
            return a.jitter < b.jitter
        }!
        return best.dir
    }

    private static func nearestFoodDistance(from p: GridPoint, foods: Set<GridPoint>) -> Int? {
        var best: Int?
        for f in foods {
            let d = abs(f.x - p.x) + abs(f.y - p.y)
            if best == nil || d < best! { best = d }
        }
        return best
    }

    /// Count reachable empty cells starting at `start`, capped at `cap`.
    /// Used as a "am I trapping myself" heuristic — larger is safer.
    private static func floodFillArea(
        from start: GridPoint,
        game: GameState,
        blocked: Set<GridPoint>,
        cap: Int
    ) -> Int {
        var seen: Set<GridPoint> = [start]
        var stack: [GridPoint] = [start]
        var count = 0
        while let p = stack.popLast() {
            count += 1
            if count >= cap { return count }
            for d in Direction.allCases {
                let n = p + d.delta
                if n.x < 0 || n.y < 0 || n.x >= game.width || n.y >= game.height { continue }
                if blocked.contains(n) { continue }
                if seen.contains(n) { continue }
                seen.insert(n)
                stack.append(n)
            }
        }
        return count
    }
}
