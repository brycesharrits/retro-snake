import Foundation
import MultipeerConnectivity

/// Wi-Fi/Bluetooth transport built on MultipeerConnectivity.
///
/// Host and joiner use the same class; the `role` decides whether we
/// advertise or browse and whether local inputs loop back (host is
/// authoritative) or ship over the wire.
///
/// With zero connected peers, a host transport behaves identically to
/// `LocalTransport`: local inputs loop back to `onInput`, snapshots go
/// nowhere. That's what makes the seam safe to use before any peer joins.
final class MultipeerTransport: NSObject, MatchTransport {
    enum Role { case host, joiner }

    /// Service type. 1–15 chars, alphanumeric + hyphen, no leading/trailing
    /// hyphen. Both sides MUST agree or discovery won't work.
    static let serviceType = "retrosnake-br"

    let localPeerId: PeerID
    let isHost: Bool

    var onPeerJoin:  ((PeerID) -> Void)?
    var onPeerLeave: ((PeerID) -> Void)?
    var onInput:     ((InputMessage) -> Void)?
    var onSnapshot:  ((GameSnapshot) -> Void)?

    private let mcPeerId: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var peerMap: [MCPeerID: PeerID] = [:]

    init(displayName: String, role: Role) {
        // Append a short random suffix so two devices with the same display
        // name don't collide on the wire (identity mapping keys off this).
        let suffix = String(UUID().uuidString.prefix(4))
        let uniqueName = "\(displayName)#\(suffix)"
        let mc = MCPeerID(displayName: uniqueName)

        self.mcPeerId = mc
        self.localPeerId = PeerID(value: uniqueName)
        self.isHost = (role == .host)
        self.session = MCSession(peer: mc,
                                 securityIdentity: nil,
                                 encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    // MARK: - Lifecycle

    func start() {
        if isHost {
            let a = MCNearbyServiceAdvertiser(peer: mcPeerId,
                                              discoveryInfo: nil,
                                              serviceType: Self.serviceType)
            a.delegate = self
            a.startAdvertisingPeer()
            self.advertiser = a
        } else {
            let b = MCNearbyServiceBrowser(peer: mcPeerId,
                                           serviceType: Self.serviceType)
            b.delegate = self
            b.startBrowsingForPeers()
            self.browser = b
        }
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        session.disconnect()
    }

    // MARK: - MatchTransport send

    func send(input: InputMessage) {
        if isHost {
            // Host is authoritative — its own inputs fold in via onInput,
            // same path as inputs received from clients. Clients only get
            // snapshots, not raw inputs.
            onInput?(input)
        } else {
            broadcast(.input(input))
        }
    }

    func send(snapshot: GameSnapshot) {
        guard isHost else { return }
        broadcast(.snapshot(snapshot))
    }

    private func broadcast(_ message: WireMessage) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            let data = try WireCodec.encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            // Best-effort; snapshots are re-sent every tick, inputs get
            // retried on next swipe. Nothing productive to do here.
        }
    }

    private func mapPeer(_ mc: MCPeerID) -> PeerID {
        if let existing = peerMap[mc] { return existing }
        let pid = PeerID(value: mc.displayName)
        peerMap[mc] = pid
        return pid
    }
}

// MARK: - MCSessionDelegate

extension MultipeerTransport: MCSessionDelegate {
    func session(_ session: MCSession,
                 peer peerID: MCPeerID,
                 didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let pid = self.mapPeer(peerID)
            switch state {
            case .connected:
                self.onPeerJoin?(pid)
            case .notConnected:
                self.peerMap.removeValue(forKey: peerID)
                self.onPeerLeave?(pid)
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession,
                 didReceive data: Data,
                 fromPeer peerID: MCPeerID) {
        guard let message = try? WireCodec.decode(data) else { return }
        DispatchQueue.main.async { [weak self] in
            switch message {
            case .input(let input):    self?.onInput?(input)
            case .snapshot(let snap):  self?.onSnapshot?(snap)
            }
        }
    }

    // Unused stream/resource paths — required by the protocol.
    func session(_ s: MCSession, didReceive stream: InputStream, withName: String, fromPeer: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName: String, fromPeer: MCPeerID, with: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName: String, fromPeer: MCPeerID, at: URL?, withError: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerTransport: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept. Lobby UI decides whether to keep the peer or kick
        // them (kick-by-disconnect will come later).
        invitationHandler(true, session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerTransport: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        // Auto-invite any host we find. Simple; matches "join first lobby
        // that shows up." A future explicit-select UI would move this call
        // behind a user tap.
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // Session state change handles connection loss; nothing extra here.
    }
}
