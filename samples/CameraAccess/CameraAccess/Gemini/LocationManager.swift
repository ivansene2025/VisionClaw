import CoreLocation
import Foundation

class LocationManager: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = 10
  }

  func requestPermissionAndStart() {
    let status = manager.authorizationStatus
    if status == .notDetermined {
      manager.requestWhenInUseAuthorization()
    } else if status == .authorizedWhenInUse || status == .authorizedAlways {
      manager.startUpdatingLocation()
    }
  }

  /// High-accuracy GPS mode for golf: best-for-navigation accuracy, 3m distance filter
  func startGolfMode() {
    manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    manager.distanceFilter = 3 // ~3 yards
    requestPermissionAndStart()
  }

  func stop() {
    manager.stopUpdatingLocation()
    // Reset to defaults
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = 10
  }

  var lastCoordinate: CLLocationCoordinate2D? {
    manager.location?.coordinate
  }

  // MARK: - CLLocationManagerDelegate

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if manager.authorizationStatus == .authorizedWhenInUse ||
       manager.authorizationStatus == .authorizedAlways {
      manager.startUpdatingLocation()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    onLocationUpdate?(location.coordinate)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    NSLog("[LocationManager] Error: %@", error.localizedDescription)
  }
}
