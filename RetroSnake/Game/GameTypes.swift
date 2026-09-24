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

struct GridPoint: Hashable {
    var x: Int
    var y: Int

    static func + (a: GridPoint, b: GridPoint) -> GridPoint {
        GridPoint(x: a.x + b.x, y: a.y + b.y)
    }
}

enum Direction: CaseIterable {
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

struct Snake: Identifiable {
    let id: Int
    var controller: Controller
    var body: [GridPoint]        // head is body[0]
    var direction: Direction
    var pendingDirection: Direction
    var alive: Bool = true
    var growth: Int = 0          // segments still to grow
    var color: Color
    var score: Int = 0

    var head: GridPoint { body[0] }
    var isPlayer: Bool { controller == .localPlayer }
    var isBot: Bool { controller == .bot }
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
