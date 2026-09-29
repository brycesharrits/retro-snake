import XCTest
@testable import RetroSnake

/// Records everything sent through it and exposes deliver hooks so tests can
/// simulate incoming peer messages. Used in place of `LocalTransport` when a
/// test needs to inspect what was sent, not just what was applied.
private final class SpyTransport: MatchTransport {
    let localPeerId = PeerID(value: "spy")
    let isHost = true

    var onPeerJoin:  ((PeerID) -> Void)?
    var onPeerLeave: ((PeerID) -> Void)?
    var onInput:     ((InputMessage) -> Void)?
    var onSnapshot:  ((GameSnapshot) -> Void)?

    private(set) var sentInputs: [InputMessage] = []
    private(set) var sentSnapshots: [GameSnapshot] = []

    func send(input: InputMessage) { sentInputs.append(input) }
    func send(snapshot: GameSnapshot) { sentSnapshots.append(snapshot) }

    // Test-side hooks to fake incoming messages.
    func deliverInput(_ msg: InputMessage) { onInput?(msg) }
    func deliverSnapshot(_ snap: GameSnapshot) { onSnapshot?(snap) }
}

final class MatchTransportTests: XCTestCase {

    // MARK: - LocalTransport

    func test_localTransportLoopsBackInput() {
        let t = LocalTransport()
        var received: InputMessage?
        t.onInput = { received = $0 }
        t.send(input: InputMessage(snakeId: 3, direction: .left, tick: 1))
        XCTAssertEqual(received?.snakeId, 3)
        XCTAssertEqual(received?.direction, .left)
        XCTAssertEqual(received?.tick, 1)
    }

    func test_localTransportSnapshotSendDoesNotLoopBack() {
        let t = LocalTransport()
        var got = 0
        t.onSnapshot = { _ in got += 1 }
        t.send(snapshot: GameSnapshot(tick: 0, matchSeed: 0, snakes: [], food: []))
        XCTAssertEqual(got, 0)
    }

    func test_localTransportIsHost() {
        XCTAssertTrue(LocalTransport().isHost)
    }

    // MARK: - GameState wiring

    func test_sendPlayerDirectionRoutesThroughTransport() {
        let g = GameState()
        let spy = SpyTransport()
        g.newGame(mode: .singlePlayer, transport: spy)

        g.sendPlayerDirection(.left)

        XCTAssertEqual(spy.sentInputs.count, 1)
        XCTAssertEqual(spy.sentInputs.first?.direction, .left)
        // Player snake gets id 0 in newGame.
        XCTAssertEqual(spy.sentInputs.first?.snakeId, 0)
    }

    func test_incomingSnapshotIsAppliedToGameState() {
        let g = GameState()
        let spy = SpyTransport()
        g.newGame(mode: .battleRoyale, transport: spy)

        let snap = GameSnapshot(
            tick: 99,
            matchSeed: 42,
            snakes: [],
            food: [GridPoint(x: 1, y: 2)]
        )
        spy.deliverSnapshot(snap)

        XCTAssertEqual(g.tick, 99)
        XCTAssertEqual(g.matchSeed, 42)
        XCTAssertTrue(g.snakes.isEmpty)
        XCTAssertEqual(g.food, [GridPoint(x: 1, y: 2)])
    }

    func test_incomingInputUpdatesPendingDirection() {
        // Fake an "input from a peer" via the transport callback and verify
        // GameState routes it through `requestDirection` — same seam local
        // swipes will use in SP.
        let g = GameState()
        let spy = SpyTransport()
        g.newGame(mode: .battleRoyale, transport: spy)

        // Player faces .up by default, so .left is a valid perpendicular.
        spy.deliverInput(InputMessage(snakeId: 0, direction: .left, tick: 0))

        XCTAssertEqual(g.snakes.first(where: { $0.isPlayer })?.pendingDirection, .left)
    }

    func test_localTransportLoopbackReachesGameStateEndToEnd() {
        // Full round-trip in single-player: swipe → sendPlayerDirection →
        // LocalTransport → onInput → requestDirection → pendingDirection.
        let g = GameState()
        g.newGame()  // defaults: singlePlayer + LocalTransport

        g.sendPlayerDirection(.left)

        XCTAssertEqual(g.snakes.first(where: { $0.isPlayer })?.pendingDirection, .left)
    }
}
