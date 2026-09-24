import Foundation
import SwiftUI

enum MatchMode {
    case singlePlayer
    case battleRoyale
}

/// Transport-agnostic peer identifier. Wrapping a plain string keeps
/// `Controller` and message types free of any framework-specific ID
/// (MCPeerID today, potentially a server-issued id later).
struct PeerID: Hashable, Codable {
    let value: String
}

enum Controller: Hashable {
    case localPlayer
    case remotePeer(PeerID)
    case bot
}

struct GridPoint: Hashable, Codable {
    var x: Int
    var y: Int

    static func + (a: GridPoint, b: GridPoint) -> GridPoint {
        GridPoint(x: a.x + b.x, y: a.y + b.y)
    }
}

enum Direction: String, CaseIterable, Codable {
    case up, down, left, right

    var delta: GridPoint {
        switch self {
        case .up:    return GridPoint(x:  0, y: -1)
        case .down:  return GridPoint(x:  0, y:  1)
        case .left:  return GridPoint(x: -1, y:  0)
        case .right: return GridPoint(x:  1, y:  0)
        }
    }

    var opposite: Direction {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}

/// Wire-safe color id. Snake carries the id; view code maps to `Color`.
/// Keeps snapshots trivially Codable and independent of SwiftUI on the wire.
enum SnakeColor: String, Codable, CaseIterable {
    case cyan, magenta, amber, acidGreen, orange

    var color: Color {
        switch self {
        case .cyan:      return .cyan
        case .magenta:   return Color(red: 1.0, green: 0.25, blue: 0.75)
        case .amber:     return Color(red: 1.0, green: 0.85, blue: 0.15)
        case .acidGreen: return Color(red: 0.35, green: 1.0, blue: 0.5)
        case .orange:    return Color(red: 1.0, green: 0.45, blue: 0.15)
        }
    }
}

struct Snake: Identifiable, Codable {
    let id: Int
    var controller: Controller
    var body: [GridPoint]        // head is body[0]
    var direction: Direction
    var pendingDirection: Direction
    var alive: Bool = true
    var growth: Int = 0          // segments still to grow
    var colorId: SnakeColor
    var score: Int = 0

    var head: GridPoint { body[0] }
    var isPlayer: Bool { controller == .localPlayer }
    var isBot: Bool { controller == .bot }
    var color: Color { colorId.color }
}

extension Controller: Codable {}

/// Full game state at one tick — what an authoritative host broadcasts,
/// and what a replay harness recomputes from `(seed, inputs)`.
struct GameSnapshot: Codable {
    let tick: Int
    let matchSeed: UInt64
    let snakes: [Snake]
    let food: Set<GridPoint>
}

/// A single direction change from any input source, tagged with the tick
/// the sender observed. Host uses `tick` for late-input reconciliation.
struct InputMessage: Codable {
    let snakeId: Int
    let direction: Direction
    let tick: Int
}

/// Seedable PRNG (SplitMix64) so a match can be replayed from `(seed, inputs)`
/// — the foundation for host→client snapshot verification and future lockstep.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
