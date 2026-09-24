import Foundation
import SwiftUI

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
    let isPlayer: Bool
    var body: [GridPoint]        // head is body[0]
    var direction: Direction
    var pendingDirection: Direction
    var alive: Bool = true
    var growth: Int = 0          // segments still to grow
    var color: Color
    var score: Int = 0

    var head: GridPoint { body[0] }
}
