import Foundation

/// The seam between `GameState` and whatever moves bytes between peers.
///
/// Concrete impls today: `LocalTransport` (single-device, loopback).
/// Planned: `MultipeerTransport` (Wi-Fi/BT), later a `WebSocketTransport`
/// hitting our own server. GameState only ever talks to this protocol,
/// so the sim never learns which backend it's running on.
protocol MatchTransport: AnyObject {
    var localPeerId: PeerID { get }
    var isHost: Bool { get }

    /// Local -> host. On the host, this is loopback; on a client, over the wire.
    func send(input: InputMessage)

    /// Host -> all clients. No-op when called from a client or in single-player.
    func send(snapshot: GameSnapshot)

    var onPeerJoin:  ((PeerID) -> Void)? { get set }
    var onPeerLeave: ((PeerID) -> Void)? { get set }

    /// Host receives an input from any peer (or its own loopback).
    var onInput: ((InputMessage) -> Void)? { get set }

    /// Client receives a snapshot from the host.
    var onSnapshot: ((GameSnapshot) -> Void)? { get set }
}

/// Single-device transport. `send(input:)` loops straight back to `onInput`
/// so the exact same input path runs in single-player as in multiplayer —
/// bugs in the seam surface immediately, not once when networking is wired.
/// `send(snapshot:)` is a drop; nothing to broadcast to.
final class LocalTransport: MatchTransport {
    let localPeerId: PeerID
    let isHost: Bool = true

    var onPeerJoin:  ((PeerID) -> Void)?
    var onPeerLeave: ((PeerID) -> Void)?
    var onInput:     ((InputMessage) -> Void)?
    var onSnapshot:  ((GameSnapshot) -> Void)?

    init(peerId: PeerID = PeerID(value: "local")) {
        self.localPeerId = peerId
    }

    func send(input: InputMessage) {
        onInput?(input)
    }

    func send(snapshot: GameSnapshot) {
        // No peers — nothing to send.
    }
}
