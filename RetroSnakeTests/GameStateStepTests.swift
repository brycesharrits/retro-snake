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
            colorId: .cyan
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

    // MARK: - Snapshot round-trip

    func test_snapshotThenApplyRestoresState() {
        let g = makeEmptyGame()
        g.tick = 42
        g.matchSeed = 0xDEADBEEF
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 5, y: 5), GridPoint(x: 4, y: 5), GridPoint(x: 3, y: 5)],
            direction: .right,
            growth: 2
        ))
        g.food = [GridPoint(x: 10, y: 10), GridPoint(x: 12, y: 8)]

        let snap = g.snapshot()

        let g2 = makeEmptyGame()
        g2.apply(snap)

        XCTAssertEqual(g2.tick, 42)
        XCTAssertEqual(g2.matchSeed, 0xDEADBEEF)
        XCTAssertEqual(g2.snakes.count, 1)
        XCTAssertEqual(g2.snakes[0].body, g.snakes[0].body)
        XCTAssertEqual(g2.snakes[0].growth, 2)
        XCTAssertEqual(g2.food, g.food)
    }

    func test_snapshotJSONRoundTrips() {
        let g = makeEmptyGame()
        g.tick = 7
        g.matchSeed = 12345
        g.snakes.append(snake(
            id: 0,
            body: [GridPoint(x: 5, y: 5), GridPoint(x: 4, y: 5), GridPoint(x: 3, y: 5)],
            direction: .right,
            controller: .remotePeer(PeerID(value: "peer-abc"))
        ))
        g.food = [GridPoint(x: 9, y: 9)]

        let data = try! JSONEncoder().encode(g.snapshot())
        let decoded = try! JSONDecoder().decode(GameSnapshot.self, from: data)

        XCTAssertEqual(decoded.tick, 7)
        XCTAssertEqual(decoded.matchSeed, 12345)
        XCTAssertEqual(decoded.snakes[0].id, 0)
        XCTAssertEqual(decoded.snakes[0].controller,
                       .remotePeer(PeerID(value: "peer-abc")))
        XCTAssertEqual(decoded.food, [GridPoint(x: 9, y: 9)])
    }

    func test_inputMessageJSONRoundTrips() {
        let msg = InputMessage(snakeId: 3, direction: .left, tick: 128)
        let data = try! JSONEncoder().encode(msg)
        let decoded = try! JSONDecoder().decode(InputMessage.self, from: data)
        XCTAssertEqual(decoded.snakeId, 3)
        XCTAssertEqual(decoded.direction, .left)
        XCTAssertEqual(decoded.tick, 128)
    }

    // MARK: - Battle Royale spawn

    func test_battleRoyaleSpawnsSixSnakesWithNoRemotePeers() {
        let g = GameState()
        g.newGame(mode: .battleRoyale)
        XCTAssertEqual(g.snakes.count, 6)
        XCTAssertEqual(g.snakes[0].controller, .localPlayer)
        // With no remote peers, seats 1..5 are all bots.
        for seat in 1...5 {
            XCTAssertEqual(g.snakes[seat].controller, .bot, "seat \(seat)")
        }
    }

    func test_battleRoyaleAssignsRemotePeersToMiddleSeats() {
        let g = GameState()
        let peers = [PeerID(value: "alice"), PeerID(value: "bob")]
        g.newGame(mode: .battleRoyale, remotePeers: peers)
        XCTAssertEqual(g.snakes.count, 6)
        XCTAssertEqual(g.snakes[0].controller, .localPlayer)
        XCTAssertEqual(g.snakes[1].controller, .remotePeer(PeerID(value: "alice")))
        XCTAssertEqual(g.snakes[2].controller, .remotePeer(PeerID(value: "bob")))
        XCTAssertEqual(g.snakes[3].controller, .bot)
        XCTAssertEqual(g.snakes[4].controller, .bot)
        XCTAssertEqual(g.snakes[5].controller, .bot)
    }

    func test_battleRoyaleSpawnsAreDistinct() {
        let g = GameState()
        g.newGame(mode: .battleRoyale)
        let heads = g.snakes.map(\.head)
        XCTAssertEqual(Set(heads).count, heads.count, "each seat must spawn at a unique cell")
    }

    // MARK: - Snapshot peer-identity round trip

    func test_snapshotExternalizesLocalPlayerToRemotePeer() {
        // A host's `.localPlayer` becomes `.remotePeer(myId)` on the wire so
        // recipients can identify which seat is which.
        let g = GameState()
        g.newGame(mode: .battleRoyale)  // default LocalTransport, peer id "local"
        let snap = g.snapshot()
        XCTAssertEqual(snap.snakes[0].controller,
                       .remotePeer(PeerID(value: "local")))
    }

    func test_applyInternalizesMatchingPeerBackToLocalPlayer() {
        // A snapshot from a "host" with our own PeerID stamped on seat 0
        // should turn back into `.localPlayer` when we apply it.
        let g = GameState()
        g.newGame(mode: .battleRoyale)
        let hostSnap = GameSnapshot(
            tick: 5, matchSeed: 0,
            snakes: [
                Snake(id: 0,
                      controller: .remotePeer(PeerID(value: "local")),
                      body: [GridPoint(x: 1, y: 1), GridPoint(x: 1, y: 2), GridPoint(x: 1, y: 3)],
                      direction: .up, pendingDirection: .up,
                      colorId: .cyan),
                Snake(id: 1,
                      controller: .remotePeer(PeerID(value: "other")),
                      body: [GridPoint(x: 5, y: 5), GridPoint(x: 5, y: 6), GridPoint(x: 5, y: 7)],
                      direction: .up, pendingDirection: .up,
                      colorId: .magenta),
            ],
            food: []
        )
        g.apply(hostSnap)
        XCTAssertEqual(g.snakes[0].controller, .localPlayer,
                       "our seat should become local")
        XCTAssertEqual(g.snakes[1].controller,
                       .remotePeer(PeerID(value: "other")),
                       "other peer's seat is left as remote")
    }

    // MARK: - Host authoritative loop

    func test_battleRoyaleClientDoesNotStartTicker() {
        let g = GameState()
        let joinerTransport = MultipeerTransport(displayName: "J", role: .joiner)
        // Skip newGame's spawn — use client session setup so we're client-shaped.
        let seed = GameSnapshot(tick: 0, matchSeed: 42, snakes: [], food: [])
        g.setupClientSession(mode: .battleRoyale, transport: joinerTransport, snapshot: seed)
        g.start()
        XCTAssertFalse(g.isRunning, "clients must not run their own tick loop")
    }

    func test_battleRoyaleHostStartsTicker() {
        let g = GameState()
        let hostTransport = MultipeerTransport(displayName: "H", role: .host)
        g.newGame(mode: .battleRoyale, transport: hostTransport)
        g.start()
        XCTAssertTrue(g.isRunning, "host drives the sim")
        g.stop()
    }

    func test_battleRoyaleStepBroadcastsSnapshotViaSpyTransport() {
        // Use a spy transport that reports itself as host so step() takes
        // the broadcast branch. Verifying a snapshot was sent (count > 0).
        let g = GameState()
        let spy = SpyHostTransport()
        g.newGame(mode: .battleRoyale, transport: spy)
        g.step()
        XCTAssertGreaterThan(spy.snapshotsSent, 0)
    }
}

/// Minimal spy for tests that only care about counting broadcasts.
private final class SpyHostTransport: MatchTransport {
    let localPeerId = PeerID(value: "spy-host")
    let isHost = true
    var onPeerJoin:  ((PeerID) -> Void)?
    var onPeerLeave: ((PeerID) -> Void)?
    var onInput:     ((InputMessage) -> Void)?
    var onSnapshot:  ((GameSnapshot) -> Void)?

    private(set) var snapshotsSent = 0

    func send(input: InputMessage) { onInput?(input) }
    func send(snapshot: GameSnapshot) { snapshotsSent += 1 }
}
