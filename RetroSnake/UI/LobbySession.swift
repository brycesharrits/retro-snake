import Foundation
import Observation

/// Config the lobby hands off to `GameView` when a match begins.
/// Host: `snapshot` is nil, `remotePeers` populated. Joiner: `snapshot`
/// carries the initial state, `remotePeers` is empty (client doesn't need it).
struct MatchStartInfo: Identifiable, Equatable {
    let id = UUID()
    let transport: MultipeerTransport
    let snapshot: GameSnapshot?
    let remotePeers: [PeerID]

    static func == (lhs: MatchStartInfo, rhs: MatchStartInfo) -> Bool {
        lhs.id == rhs.id
    }
}

/// Owns the `MultipeerTransport` while the user is in the lobby, tracks
/// connected peers, and produces a `MatchStartInfo` when either the host
/// taps START or the joiner receives the first snapshot.
@Observable
final class LobbySession {
    private static let displayNameKey = "retrosnake.displayName"

    var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: Self.displayNameKey) }
    }
    var connectedPeers: [PeerID] = []
    var role: MultipeerTransport.Role?
    var matchStart: MatchStartInfo?
    var isConnected: Bool = false

    /// Not observed — SwiftUI doesn't need to react to the reference itself
    /// changing, only to the `isConnected` bool and the peer list. Kept
    /// accessible so the transport can be handed off to `GameView`.
    @ObservationIgnored private(set) var transport: MultipeerTransport?

    init() {
        self.displayName = UserDefaults.standard.string(forKey: Self.displayNameKey)
            ?? "Player"
    }

    func host() {
        let t = MultipeerTransport(displayName: displayName, role: .host)
        wire(t)
        t.start()
        self.transport = t
        self.role = .host
        self.isConnected = true
    }

    func join() {
        let t = MultipeerTransport(displayName: displayName, role: .joiner)
        wire(t)
        t.start()
        self.transport = t
        self.role = .joiner
        self.isConnected = true
    }

    /// Host taps START. Hands GameView the peer roster; GameView builds
    /// the initial state and the first tick's snapshot broadcast tells
    /// clients the match is live.
    func startMatch() {
        guard role == .host, let t = transport else { return }
        matchStart = MatchStartInfo(
            transport: t,
            snapshot: nil,
            remotePeers: connectedPeers
        )
    }

    func stop() {
        transport?.stop()
        transport = nil
        role = nil
        connectedPeers.removeAll()
        matchStart = nil
        isConnected = false
    }

    private func wire(_ t: MultipeerTransport) {
        t.onPeerJoin = { [weak self] pid in
            self?.connectedPeers.append(pid)
        }
        t.onPeerLeave = { [weak self] pid in
            self?.connectedPeers.removeAll { $0 == pid }
        }
        t.onSnapshot = { [weak self] snap in
            // Joiner path: first snapshot from host = match started.
            guard let self, self.role == .joiner, self.matchStart == nil,
                  let t = self.transport else { return }
            self.matchStart = MatchStartInfo(
                transport: t,
                snapshot: snap,
                remotePeers: []
            )
        }
    }
}
