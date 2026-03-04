import CoreLocation
import Foundation

// MARK: - Models

struct GolfCourse {
  let id: String
  let name: String
  let city: String
  let state: String
  let country: String
  let lat: Double
  let lng: Double
  let holes: [GolfHoleData]
}

struct GolfHoleData {
  let number: Int
  let par: Int
  let yardage: Int
  let handicapIndex: Int?
  let greenLatitude: Double?
  let greenLongitude: Double?
}

// MARK: - Service

@MainActor
class GolfCourseAPIService {
  static let shared = GolfCourseAPIService()

  private let baseURL = "https://api.golfcourseapi.com/v1"
  private var apiKey: String { SettingsManager.shared.golfCourseAPIKey }

  var activeCourse: GolfCourse?

  private init() {}

  var isConfigured: Bool {
    !apiKey.isEmpty
  }

  // MARK: - API Methods

  /// Search for courses near a GPS coordinate
  func searchNearbyCourses(lat: Double, lng: Double, radius: Int = 10) async -> [GolfCourse] {
    guard isConfigured else {
      NSLog("[GolfCourseAPI] No API key configured")
      return []
    }

    let urlString = "\(baseURL)/courses?lat=\(lat)&lng=\(lng)&radius=\(radius)"
    guard let url = URL(string: urlString) else { return [] }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        NSLog("[GolfCourseAPI] Search failed: %@", String(data: data, encoding: .utf8) ?? "unknown error")
        return []
      }

      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let coursesArray = json["courses"] as? [[String: Any]] else {
        return []
      }

      return coursesArray.compactMap { parseCourse($0) }
    } catch {
      NSLog("[GolfCourseAPI] Search error: %@", error.localizedDescription)
      return []
    }
  }

  /// Get full course details including hole data
  func getCourseDetails(courseId: String) async -> GolfCourse? {
    guard isConfigured else { return nil }

    let urlString = "\(baseURL)/courses/\(courseId)"
    guard let url = URL(string: urlString) else { return nil }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        NSLog("[GolfCourseAPI] Details failed: %@", String(data: data, encoding: .utf8) ?? "unknown error")
        return nil
      }

      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
      }

      return parseCourse(json)
    } catch {
      NSLog("[GolfCourseAPI] Details error: %@", error.localizedDescription)
      return nil
    }
  }

  /// Convenience: search nearby + get details of nearest course
  func loadNearestCourse(lat: Double, lng: Double) async -> GolfCourse? {
    let courses = await searchNearbyCourses(lat: lat, lng: lng)
    guard let nearest = courses.first else {
      NSLog("[GolfCourseAPI] No courses found near %.4f, %.4f", lat, lng)
      return nil
    }

    // If the search already returned hole data, use it directly
    if !nearest.holes.isEmpty {
      activeCourse = nearest
      return nearest
    }

    // Otherwise fetch full details
    if let detailed = await getCourseDetails(courseId: nearest.id) {
      activeCourse = detailed
      return detailed
    }

    // Fall back to basic course info
    activeCourse = nearest
    return nearest
  }

  // MARK: - Distance Calculation

  /// Calculate distance from current position to green in yards
  func distanceToGreen(from coord: CLLocationCoordinate2D, hole: GolfHoleData) -> Int? {
    guard let greenLat = hole.greenLatitude, let greenLng = hole.greenLongitude else {
      return nil
    }

    let currentLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
    let greenLocation = CLLocation(latitude: greenLat, longitude: greenLng)

    let distanceMeters = currentLocation.distance(from: greenLocation)
    let distanceYards = Int(distanceMeters * 1.09361)

    return distanceYards
  }

  /// Estimate distance to green using hole yardage and tee-to-current distance
  /// Fallback when green coordinates are not available
  func estimateDistanceToGreen(from coord: CLLocationCoordinate2D, hole: GolfHoleData, teeCoord: CLLocationCoordinate2D?) -> Int? {
    // If we have green coordinates, use precise calculation
    if let precise = distanceToGreen(from: coord, hole: hole) {
      return precise
    }

    // Fallback: estimate based on how far from tee we've walked vs hole yardage
    guard let teeCoord = teeCoord else {
      return hole.yardage // Best guess: full hole yardage
    }

    let teeLocation = CLLocation(latitude: teeCoord.latitude, longitude: teeCoord.longitude)
    let currentLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
    let walkedYards = Int(teeLocation.distance(from: currentLocation) * 1.09361)

    return max(0, hole.yardage - walkedYards)
  }

  // MARK: - Clear

  func clearActiveCourse() {
    activeCourse = nil
  }

  // MARK: - Parsing

  private func parseCourse(_ json: [String: Any]) -> GolfCourse? {
    guard let id = json["id"] as? String ?? (json["id"] as? Int).map({ String($0) }),
          let name = json["name"] as? String else {
      return nil
    }

    let city = json["city"] as? String ?? ""
    let state = json["state"] as? String ?? ""
    let country = json["country"] as? String ?? ""
    let lat = json["latitude"] as? Double ?? json["lat"] as? Double ?? 0
    let lng = json["longitude"] as? Double ?? json["lng"] as? Double ?? 0

    var holes: [GolfHoleData] = []
    if let holesArray = json["holes"] as? [[String: Any]] {
      holes = holesArray.compactMap { holeJson in
        guard let number = holeJson["number"] as? Int ?? holeJson["hole_number"] as? Int,
              let par = holeJson["par"] as? Int else {
          return nil
        }
        let yardage = holeJson["yardage"] as? Int ?? holeJson["yards"] as? Int ?? 0
        let handicapIndex = holeJson["handicap_index"] as? Int ?? holeJson["handicap"] as? Int
        let greenLat = holeJson["green_latitude"] as? Double ?? holeJson["greenLat"] as? Double
        let greenLng = holeJson["green_longitude"] as? Double ?? holeJson["greenLng"] as? Double

        return GolfHoleData(
          number: number,
          par: par,
          yardage: yardage,
          handicapIndex: handicapIndex,
          greenLatitude: greenLat,
          greenLongitude: greenLng
        )
      }.sorted { $0.number < $1.number }
    }

    return GolfCourse(
      id: id,
      name: name,
      city: city,
      state: state,
      country: country,
      lat: lat,
      lng: lng,
      holes: holes
    )
  }
}
