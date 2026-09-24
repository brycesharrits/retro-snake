import Foundation
import SwiftUI
import Observation

@Observable
final class GameState {
    // Board
    let width: Int = 20
    let height: Int = 30

    // Entities
    var snakes: [Snake] = []
    var food: Set<GridPoint> = []

    // Meta
    var tick: Int = 0
    var isRunning: Bool = false
    var isGameOver: Bool = false
    var mode: MatchMode = .singlePlayer

    // Config
    let botCount: Int = 3
    let targetFoodCount: Int = 6
    var tickInterval: TimeInterval { max(0.06, 0.14 - Double(playerLength) * 0.002) }

    private var timer: Timer?
    private var rng = SystemRandomNumberGenerator()

    var playerLength: Int { snakes.first(where: { $0.isPlayer })?.body.count ?? 0 }
    var playerAlive: Bool { snakes.first(where: { $0.isPlayer })?.alive ?? false }
    var aliveBotCount: Int { snakes.filter { !$0.isPlayer && $0.alive }.count }

    // MARK: - Lifecycle

    func newGame(mode: MatchMode = .singlePlayer) {
        self.mode = mode
        snakes.removeAll()
        food.removeAll()
        tick = 0
        isGameOver = false

        // Player spawns in the middle heading up
        let playerStart = GridPoint(x: width / 2, y: height * 2 / 3)
        snakes.append(Snake(
            id: 0,
            isPlayer: true,
            body: initialBody(at: playerStart, direction: .up),
            direction: .up,
            pendingDirection: .up,
            color: .cyan
        ))

        // Bots evenly distributed
        let botColors: [Color] = [
            Color(red: 1.0, green: 0.25, blue: 0.75),  // magenta/pink
            Color(red: 1.0, green: 0.85, blue: 0.15),  // amber
            Color(red: 0.35, green: 1.0, blue: 0.5),   // acid green
            Color(red: 1.0, green: 0.45, blue: 0.15),  // orange
        ]
        for i in 0..<botCount {
            let col = 2 + (i * (width - 4)) / max(1, botCount - 1)
            let row = height / 4
            let dir: Direction = (i % 2 == 0) ? .down : .up
            snakes.append(Snake(
                id: i + 1,
                isPlayer: false,
                body: initialBody(at: GridPoint(x: col, y: row), direction: dir),
                direction: dir,
                pendingDirection: dir,
                color: botColors[i % botColors.count]
            ))
        }

        while food.count < targetFoodCount { spawnFood() }
    }

    private func initialBody(at head: GridPoint, direction: Direction) -> [GridPoint] {
        let back = direction.opposite.delta
        return (0..<3).map { GridPoint(x: head.x + back.x * $0, y: head.y + back.y * $0) }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleTick()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func scheduleTick() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: false) { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.step()
            self.scheduleTick()
        }
    }

    // MARK: - Input

    func requestPlayerDirection(_ dir: Direction) {
        guard let idx = snakes.firstIndex(where: { $0.isPlayer }), snakes[idx].alive else { return }
        // Can't reverse into your own neck
        if dir == snakes[idx].direction.opposite { return }
        snakes[idx].pendingDirection = dir
    }

    // MARK: - Tick

    func step() {
        tick += 1

        // Bot decisions first
        for i in snakes.indices where !snakes[i].isPlayer && snakes[i].alive {
            let dir = BotAI.decide(for: snakes[i], in: self)
            if dir != snakes[i].direction.opposite {
                snakes[i].pendingDirection = dir
            }
        }

        // Commit pending directions
        for i in snakes.indices where snakes[i].alive {
            snakes[i].direction = snakes[i].pendingDirection
        }

        // Compute new heads
        var newHeads: [Int: GridPoint] = [:]
        for i in snakes.indices where snakes[i].alive {
            newHeads[i] = snakes[i].head + snakes[i].direction.delta
        }

        // Determine who dies this tick
        var dying: Set<Int> = []

        // Wall collisions
        for (i, head) in newHeads {
            if head.x < 0 || head.y < 0 || head.x >= width || head.y >= height {
                dying.insert(i)
            }
        }

        // Head-on collisions (two heads landing on the same cell)
        let headGroups = Dictionary(grouping: newHeads) { $0.value }
        for (_, group) in headGroups where group.count > 1 {
            for entry in group { dying.insert(entry.key) }
        }

        // Body collisions — check new head against every occupied cell except each snake's own tail
        // (tail moves out of the way unless growing).
        let occupied = occupiedCells(excludingTailsWhenNotGrowing: true)
        for (i, head) in newHeads {
            if dying.contains(i) { continue }
            if occupied.contains(head) { dying.insert(i) }
        }

        // Apply moves + food
        var eatenFood: Set<GridPoint> = []
        for i in snakes.indices where snakes[i].alive {
            guard let head = newHeads[i] else { continue }
            if dying.contains(i) {
                snakes[i].alive = false
                continue
            }
            snakes[i].body.insert(head, at: 0)
            if food.contains(head) {
                eatenFood.insert(head)
                snakes[i].growth += 1
                snakes[i].score += 1
            }
            if snakes[i].growth > 0 {
                snakes[i].growth -= 1
            } else {
                snakes[i].body.removeLast()
            }
        }
        food.subtract(eatenFood)

        while food.count < targetFoodCount { spawnFood() }

        if !playerAlive {
            isGameOver = true
            stop()
        }
    }

    // MARK: - Helpers

    /// Set of cells currently occupied by any live snake. When
    /// `excludingTailsWhenNotGrowing` is true, each snake's tail cell is
    /// omitted because it will vacate on the next step (unless the snake is
    /// mid-growth).
    func occupiedCells(excludingTailsWhenNotGrowing: Bool) -> Set<GridPoint> {
        var cells: Set<GridPoint> = []
        for s in snakes where s.alive {
            let drop = (excludingTailsWhenNotGrowing && s.growth == 0) ? 1 : 0
            for cell in s.body.dropLast(drop) { cells.insert(cell) }
        }
        return cells
    }

    private func spawnFood() {
        let occupied = occupiedCells(excludingTailsWhenNotGrowing: false).union(food)
        // Try random spots first; fall back to scan if the board is dense.
        for _ in 0..<50 {
            let p = GridPoint(x: Int.random(in: 0..<width, using: &rng),
                              y: Int.random(in: 0..<height, using: &rng))
            if !occupied.contains(p) { food.insert(p); return }
        }
        for y in 0..<height {
            for x in 0..<width {
                let p = GridPoint(x: x, y: y)
                if !occupied.contains(p) { food.insert(p); return }
            }
        }
    }
}
