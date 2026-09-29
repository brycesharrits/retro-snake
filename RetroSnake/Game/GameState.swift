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
    var matchSeed: UInt64 = 0

    // Config
    let botCount: Int = 3
    let targetFoodCount: Int = 6
    var tickInterval: TimeInterval { max(0.06, 0.14 - Double(playerLength) * 0.002) }

    private var timer: Timer?
    private var rng = SplitMix64(seed: UInt64.random(in: .min ... .max))

    /// Message pipe to peers. Defaults to a single-device loopback so the
    /// input path is uniform in SP and MP — `sendPlayerDirection` always
    /// goes through the transport. Reassigned in `newGame(transport:)`.
    @ObservationIgnored var transport: MatchTransport = LocalTransport()

    var playerLength: Int { snakes.first(where: { $0.isPlayer })?.body.count ?? 0 }
    var playerAlive: Bool { snakes.first(where: { $0.isPlayer })?.alive ?? false }
    var aliveBotCount: Int { snakes.filter { !$0.isPlayer && $0.alive }.count }

    // MARK: - Lifecycle

    func newGame(mode: MatchMode = .singlePlayer,
                 seed: UInt64? = nil,
                 transport: MatchTransport? = nil,
                 remotePeers: [PeerID] = []) {
        self.mode = mode
        self.matchSeed = seed ?? UInt64.random(in: .min ... .max)
        self.rng = SplitMix64(seed: matchSeed)
        if let transport { self.transport = transport }
        wireTransport()
        snakes.removeAll()
        food.removeAll()
        tick = 0
        isGameOver = false

        switch mode {
        case .singlePlayer: spawnSinglePlayerSnakes()
        case .battleRoyale: spawnBattleRoyaleSnakes(remotePeers: remotePeers)
        }

        while food.count < targetFoodCount { spawnFood() }
    }

    /// Client-side setup for a match already in progress on the host.
    /// Skips spawning; the snapshot is the source of truth for state.
    func setupClientSession(mode: MatchMode,
                            transport: MatchTransport,
                            snapshot: GameSnapshot) {
        self.mode = mode
        self.transport = transport
        wireTransport()
        isGameOver = false
        apply(snapshot)
    }

    private func spawnSinglePlayerSnakes() {
        let playerStart = GridPoint(x: width / 2, y: height * 2 / 3)
        snakes.append(Snake(
            id: 0,
            controller: .localPlayer,
            body: initialBody(at: playerStart, direction: .up),
            direction: .up,
            pendingDirection: .up,
            colorId: .cyan
        ))

        let botColorIds: [SnakeColor] = [.magenta, .amber, .acidGreen, .orange]
        for i in 0..<botCount {
            let col = 2 + (i * (width - 4)) / max(1, botCount - 1)
            let row = height / 4
            let dir: Direction = (i % 2 == 0) ? .down : .up
            snakes.append(Snake(
                id: i + 1,
                controller: .bot,
                body: initialBody(at: GridPoint(x: col, y: row), direction: dir),
                direction: dir,
                pendingDirection: dir,
                colorId: botColorIds[i % botColorIds.count]
            ))
        }
    }

    /// Six-seat BR spawn: seat 0 = local player, seats 1..N = remote humans,
    /// remaining seats bot-filled. Spawn positions are fixed and distributed
    /// so nobody starts on a collision course.
    private func spawnBattleRoyaleSnakes(remotePeers: [PeerID]) {
        let spawns: [(GridPoint, Direction)] = [
            (GridPoint(x: width / 2, y: height - 4), .up),
            (GridPoint(x: width / 2, y: 3), .down),
            (GridPoint(x: 3, y: height / 2), .right),
            (GridPoint(x: width - 4, y: height / 2), .left),
            (GridPoint(x: 3, y: 3), .down),
            (GridPoint(x: width - 4, y: height - 4), .up),
        ]
        let colors: [SnakeColor] = [.cyan, .magenta, .amber, .acidGreen, .orange, .violet]

        for seat in 0..<spawns.count {
            let (spawn, dir) = spawns[seat]
            let controller: Controller
            if seat == 0 {
                controller = .localPlayer
            } else if seat - 1 < remotePeers.count {
                controller = .remotePeer(remotePeers[seat - 1])
            } else {
                controller = .bot
            }
            snakes.append(Snake(
                id: seat,
                controller: controller,
                body: initialBody(at: spawn, direction: dir),
                direction: dir,
                pendingDirection: dir,
                colorId: colors[seat]
            ))
        }
    }

    // MARK: - Snapshot / apply

    /// Produce a wire-friendly snapshot. The local player's controller is
    /// externalized to `.remotePeer(myPeerId)` so every seat is identified
    /// by a PeerID on the wire — the receiver decides which one is theirs.
    func snapshot() -> GameSnapshot {
        let myId = transport.localPeerId
        let externalized: [Snake] = snakes.map { s in
            var copy = s
            if copy.controller == .localPlayer {
                copy.controller = .remotePeer(myId)
            }
            return copy
        }
        return GameSnapshot(tick: tick, matchSeed: matchSeed,
                            snakes: externalized, food: food)
    }

    /// Overwrite live state with a snapshot from the host. Any `.remotePeer`
    /// whose PeerID matches this device is internalized to `.localPlayer`
    /// so all local logic (input routing, HUD, "isPlayer" checks) works.
    /// Doesn't touch `mode` (match-level, not per-tick).
    func apply(_ snapshot: GameSnapshot) {
        let myId = transport.localPeerId
        self.snakes = snapshot.snakes.map { s in
            var copy = s
            if case .remotePeer(let pid) = copy.controller, pid == myId {
                copy.controller = .localPlayer
            }
            return copy
        }
        self.tick = snapshot.tick
        self.matchSeed = snapshot.matchSeed
        self.food = snapshot.food
    }

    private func initialBody(at head: GridPoint, direction: Direction) -> [GridPoint] {
        let back = direction.opposite.delta
        return (0..<3).map { GridPoint(x: head.x + back.x * $0, y: head.y + back.y * $0) }
    }

    func start() {
        guard !isRunning else { return }
        // In BR, only the host runs the sim. Clients render snapshots.
        if mode == .battleRoyale && !transport.isHost { return }
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

    /// General input entry point. Route ALL direction inputs through this —
    /// local swipe, remote-peer messages, and (via `BotAI`) bot decisions —
    /// so a single seam holds the reverse-onto-neck rule.
    func requestDirection(snakeId: Int, dir: Direction) {
        guard let idx = snakes.firstIndex(where: { $0.id == snakeId }),
              snakes[idx].alive else { return }
        if dir == snakes[idx].direction.opposite { return }
        snakes[idx].pendingDirection = dir
    }

    func requestPlayerDirection(_ dir: Direction) {
        guard let player = snakes.first(where: { $0.isPlayer }) else { return }
        requestDirection(snakeId: player.id, dir: dir)
    }

    /// The path UI swipes should take. Wraps the input in an `InputMessage`
    /// tagged with the current tick and hands it to the transport — which
    /// loops it back in SP or ships it to the host in MP.
    func sendPlayerDirection(_ dir: Direction) {
        guard let player = snakes.first(where: { $0.isPlayer }) else { return }
        transport.send(input: InputMessage(
            snakeId: player.id, direction: dir, tick: tick
        ))
    }

    private func wireTransport() {
        transport.onInput = { [weak self] msg in
            self?.requestDirection(snakeId: msg.snakeId, dir: msg.direction)
        }
        transport.onSnapshot = { [weak self] snap in
            self?.apply(snap)
        }
    }

    // MARK: - Tick

    func step() {
        tick += 1

        // Bot decisions first
        for i in snakes.indices where snakes[i].isBot && snakes[i].alive {
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

        // Host broadcasts state each tick in BR mode. Clients render the
        // resulting snapshot via transport.onSnapshot → apply(_:).
        if mode == .battleRoyale && transport.isHost {
            transport.send(snapshot: snapshot())
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
