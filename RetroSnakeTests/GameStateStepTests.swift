import XCTest
import SwiftUI
@testable import RetroSnake

/// Tests for `GameState.step()` — the collision, growth, and food rules.
///
/// All snakes are constructed with `isPlayer: true` so `BotAI` never runs
/// during a step; that lets each test pin exact directions without the AI
/// second-guessing them.
final class GameStateStepTests: XCTestCase {

    // MARK: - Fixture helpers

    private func makeEmptyGame() -> GameState {
        let g = GameState()
        g.snakes.removeAll()
        g.food.removeAll()
        return g
    }

    private func snake(
        id: Int,
        body: [GridPoint],
        direction: Direction,
        growth: Int = 0,
        controller: Controller = .localPlayer
    ) -> Snake {
        Snake(
            id: id,
            controller: controller,
            body: body,
            direction: direction,
            pendingDirection: direction,
            growth: growth,
            color: .cyan
        )
    }

    // MARK: - Wall collisions

    func test_movingIntoLeftWallKills() {
        let g = makeEmptyGame()
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 0, y: 5), GridPoint(x: 1, y: 5), GridPoint(x: 2, y: 5)],
            direction: .left
        ))
        g.step()
        XCTAssertFalse(g.snakes[0].alive)
        XCTAssertTrue(g.isGameOver)
    }

    func test_movingIntoRightWallKills() {
        let g = makeEmptyGame()
        let x = g.width - 1
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: x, y: 5), GridPoint(x: x - 1, y: 5), GridPoint(x: x - 2, y: 5)],
            direction: .right
        ))
        g.step()
        XCTAssertFalse(g.snakes[0].alive)
    }

    func test_movingIntoTopWallKills() {
        let g = makeEmptyGame()
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 5, y: 0), GridPoint(x: 5, y: 1), GridPoint(x: 5, y: 2)],
            direction: .up
        ))
        g.step()
        XCTAssertFalse(g.snakes[0].alive)
    }

    // MARK: - Head-on collisions

    func test_twoHeadsIntoSameCellKillsBoth() {
        let g = makeEmptyGame()
        // Both heads will land on (11,10).
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 10, y: 10), GridPoint(x: 9, y: 10), GridPoint(x: 8, y: 10)],
            direction: .right
        ))
        g.snakes.append(snake(
            id: 1,
            body: [GridPoint(x: 12, y: 10), GridPoint(x: 13, y: 10), GridPoint(x: 14, y: 10)],
            direction: .left
        ))
        g.step()
        XCTAssertFalse(g.snakes[0].alive)
        XCTAssertFalse(g.snakes[1].alive)
    }

    // MARK: - Body collisions

    func test_movingIntoOtherSnakeBodyKills() {
        let g = makeEmptyGame()
        // Player will move (5,5) → (6,5). Other snake has a mid-body segment at (6,5).
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 5, y: 5), GridPoint(x: 4, y: 5), GridPoint(x: 3, y: 5)],
            direction: .right
        ))
        g.snakes.append(snake(
            id: 1,
            body: [GridPoint(x: 6, y: 4), GridPoint(x: 6, y: 5), GridPoint(x: 6, y: 6)],
            direction: .up
        ))
        g.step()
        XCTAssertFalse(g.snakes[0].alive)
    }

    // MARK: - Tail vacating

    func test_movingIntoVacatingTailIsSafe() {
        // Both snakes move this tick. The target cell for snake 0's new head is
        // (5,5), which is snake 1's current tail — but snake 1 also moves, so
        // its tail vacates. Both survive.
        let g = makeEmptyGame()
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 4, y: 5), GridPoint(x: 3, y: 5), GridPoint(x: 2, y: 5)],
            direction: .right
        ))
        g.snakes.append(snake(
            id: 1,
            body: [GridPoint(x: 5, y: 3), GridPoint(x: 5, y: 4), GridPoint(x: 5, y: 5)],
            direction: .up
        ))
        g.step()
        XCTAssertTrue(g.snakes[0].alive)
        XCTAssertTrue(g.snakes[1].alive)
    }

    func test_movingIntoGrowingSnakesTailKills() {
        // Same geometry as above, but snake 1 is mid-growth so its tail does
        // NOT vacate this tick — the target cell stays occupied.
        let g = makeEmptyGame()
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 4, y: 5), GridPoint(x: 3, y: 5), GridPoint(x: 2, y: 5)],
            direction: .right
        ))
        g.snakes.append(snake(
            id: 1,
            body: [GridPoint(x: 5, y: 3), GridPoint(x: 5, y: 4), GridPoint(x: 5, y: 5)],
            direction: .up,
            growth: 1
        ))
        g.step()
        XCTAssertFalse(g.snakes[0].alive)
    }

    // MARK: - Food

    func test_eatingFoodIncrementsScoreAndRemovesFood() {
        let g = makeEmptyGame()
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 4, y: 5), GridPoint(x: 3, y: 5), GridPoint(x: 2, y: 5)],
            direction: .right
        ))
        let bite = GridPoint(x: 5, y: 5)
        g.food.insert(bite)
        g.step()
        XCTAssertEqual(g.snakes[0].score, 1)
        XCTAssertFalse(g.food.contains(bite))
    }

    func test_eatingFoodGrowsSnakeByOne() {
        let g = makeEmptyGame()
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 4, y: 5), GridPoint(x: 3, y: 5), GridPoint(x: 2, y: 5)],
            direction: .right
        ))
        g.food.insert(GridPoint(x: 5, y: 5))
        let startLen = g.snakes[0].body.count
        g.step()
        XCTAssertEqual(g.snakes[0].body.count, startLen + 1)
    }

    func test_foodRespawnsToTargetCount() {
        let g = makeEmptyGame()
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 4, y: 5), GridPoint(x: 3, y: 5), GridPoint(x: 2, y: 5)],
            direction: .right
        ))
        g.food.insert(GridPoint(x: 5, y: 5))
        g.step()
        XCTAssertEqual(g.food.count, g.targetFoodCount)
    }

    // MARK: - Input guard

    func test_requestReverseIsIgnored() {
        let g = makeEmptyGame()
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 5, y: 5), GridPoint(x: 5, y: 6), GridPoint(x: 5, y: 7)],
            direction: .up
        ))
        g.requestPlayerDirection(.down)
        XCTAssertEqual(g.snakes[0].pendingDirection, .up)
    }

    func test_requestPerpendicularIsAccepted() {
        let g = makeEmptyGame()
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 5, y: 5), GridPoint(x: 5, y: 6), GridPoint(x: 5, y: 7)],
            direction: .up
        ))
        g.requestPlayerDirection(.left)
        XCTAssertEqual(g.snakes[0].pendingDirection, .left)
    }
}
