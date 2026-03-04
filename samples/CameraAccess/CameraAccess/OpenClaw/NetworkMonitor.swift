import Foundation
import Network

/// Monitors network path changes and exposes the current interface type.
/// On cellular, VisionClaw skips LAN and goes straight to the tunnel.
final class NetworkMonitor: ObservableObject {
  static let shared = NetworkMonitor()

  enum NetworkType: String {
    case wifi
    case cellular
    case wired
    case none
  }

  @Published private(set) var networkType: NetworkType = .wifi
  @Published private(set) var isConnected: Bool = true

  /// Fires whenever the network path changes (WiFi ↔ cellular, connect/disconnect).
  var onNetworkChange: ((NetworkType) -> Void)?

  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "com.visionclaw.networkmonitor", qos: .utility)

  private init() {
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      let newType: NetworkType
      let connected = path.status == .satisfied

      if path.usesInterfaceType(.wifi) {
        newType = .wifi
      } else if path.usesInterfaceType(.cellular) {
        newType = .cellular
      } else if path.usesInterfaceType(.wiredEthernet) {
        newType = .wired
      } else {
        newType = connected ? .wifi : .none
      }

      let changed = newType != self.networkType
      DispatchQueue.main.async {
        self.networkType = newType
        self.isConnected = connected
        if changed {
          NSLog("[Network] Changed to %@ (connected: %@)", newType.rawValue, connected ? "yes" : "no")
          self.onNetworkChange?(newType)
        }
      }
    }
    monitor.start(queue: queue)
    NSLog("[Network] Monitor started")
  }

  var isCellular: Bool { networkType == .cellular }
  var isWiFi: Bool { networkType == .wifi }
}
