import XCTest
@testable import RetroSnake

final class MultipeerTransportTests: XCTestCase {

    // MARK: - WireMessage codec

    func test_wireEncodesAndDecodesInput() throws {
        let msg: WireMessage = .input(InputMessage(snakeId: 2, direction: .right, tick: 5))
        let data = try WireCodec.encode(msg)
        let decoded = try WireCodec.decode(data)
        guard case .input(let input) = decoded else {
            XCTFail("Decoded as wrong case: \(decoded)"); return
        }
        XCTAssertEqual(input.snakeId, 2)
        XCTAssertEqual(input.direction, .right)
        XCTAssertEqual(input.tick, 5)
    }

    func test_wireEncodesAndDecodesSnapshot() throws {
        let snap = GameSnapshot(
            tick: 100,
            matchSeed: 0xC0FFEE,
            snakes: [],
            food: [GridPoint(x: 3, y: 4)]
        )
        let data = try WireCodec.encode(.snapshot(snap))
        let decoded = try WireCodec.decode(data)
        guard case .snapshot(let s) = decoded else {
            XCTFail("Decoded as wrong case: \(decoded)"); return
        }
        XCTAssertEqual(s.tick, 100)
        XCTAssertEqual(s.matchSeed, 0xC0FFEE)
        XCTAssertEqual(s.food, [GridPoint(x: 3, y: 4)])
    }

    func test_wireDiscriminatorFailsOnGarbage() {
        let garbage = Data([0x00, 0x01, 0x02])
        XCTAssertThrowsError(try WireCodec.decode(garbage))
    }

    // MARK: - Role wiring

    func test_hostTransportReportsIsHost() {
        let t = MultipeerTransport(displayName: "TestHost", role: .host)
        XCTAssertTrue(t.isHost)
    }

    func test_joinerTransportReportsIsNotHost() {
        let t = MultipeerTransport(displayName: "TestJoin", role: .joiner)
        XCTAssertFalse(t.isHost)
    }

    func test_localPeerIdIncludesDisplayName() {
        let t = MultipeerTransport(displayName: "Alice", role: .host)
        XCTAssertTrue(t.localPeerId.value.hasPrefix("Alice#"),
                      "expected localPeerId to start with 'Alice#', got \(t.localPeerId.value)")
    }

    // MARK: - Host loopback (0 peers)

    func test_hostSendInputLoopsBackToOnInputEvenWithNoPeers() {
        // With no peers connected, a host transport should still deliver
        // its own inputs to onInput — the same behavior as LocalTransport.
        // This lets single-device flows work through MultipeerTransport if
        // it happens to be the active transport before anyone joins.
        let t = MultipeerTransport(displayName: "Solo", role: .host)
        var received: InputMessage?
        t.onInput = { received = $0 }
        t.send(input: InputMessage(snakeId: 0, direction: .up, tick: 7))
        XCTAssertEqual(received?.snakeId, 0)
        XCTAssertEqual(received?.direction, .up)
        XCTAssertEqual(received?.tick, 7)
    }

    func test_hostSendSnapshotWithNoPeersDoesNotCrash() {
        let t = MultipeerTransport(displayName: "Solo", role: .host)
        // Should be a no-op broadcast (connectedPeers is empty).
        t.send(snapshot: GameSnapshot(tick: 0, matchSeed: 0, snakes: [], food: []))
    }

    func test_joinerSendInputWithNoPeersDoesNotLoopBack() {
        // Client mode never loops back locally — inputs must reach the host
        // via the wire. With no peers, the message is dropped silently.
        let t = MultipeerTransport(displayName: "Client", role: .joiner)
        var got = 0
        t.onInput = { _ in got += 1 }
        t.send(input: InputMessage(snakeId: 0, direction: .down, tick: 1))
        XCTAssertEqual(got, 0)
    }

    func test_joinerSendSnapshotIsNoOp() {
        // Only hosts broadcast snapshots. Client calls are silently dropped.
        let t = MultipeerTransport(displayName: "Client", role: .joiner)
        var got = 0
        t.onSnapshot = { _ in got += 1 }
        t.send(snapshot: GameSnapshot(tick: 5, matchSeed: 0, snakes: [], food: []))
        XCTAssertEqual(got, 0)
    }
}
