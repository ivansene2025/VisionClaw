import Foundation

/// Golf club distance model calibrated from a single reference club (7-iron).
/// Ratios derived from standard loft progressions and launch physics:
/// each ~3-4° loft decrease adds ~12-15 yards of carry at moderate swing speeds.
enum ClubDistanceModel {

  struct ClubInfo {
    let name: String       // e.g. "7i"
    let fullName: String   // e.g. "7-Iron"
    let ratio: Double      // relative to 7-iron carry
    let category: Category

    enum Category { case wood, hybrid, iron, wedge }
  }

  /// Standard bag ordered long → short. Ratios are relative to 7-iron carry.
  static let clubs: [ClubInfo] = [
    ClubInfo(name: "Dr",  fullName: "Driver",    ratio: 1.714, category: .wood),
    ClubInfo(name: "3w",  fullName: "3-Wood",    ratio: 1.536, category: .wood),
    ClubInfo(name: "5w",  fullName: "5-Wood",    ratio: 1.429, category: .wood),
    ClubInfo(name: "4h",  fullName: "4-Hybrid",  ratio: 1.321, category: .hybrid),
    ClubInfo(name: "5i",  fullName: "5-Iron",    ratio: 1.179, category: .iron),
    ClubInfo(name: "6i",  fullName: "6-Iron",    ratio: 1.086, category: .iron),
    ClubInfo(name: "7i",  fullName: "7-Iron",    ratio: 1.000, category: .iron),
    ClubInfo(name: "8i",  fullName: "8-Iron",    ratio: 0.914, category: .iron),
    ClubInfo(name: "9i",  fullName: "9-Iron",    ratio: 0.829, category: .iron),
    ClubInfo(name: "PW",  fullName: "PW",        ratio: 0.750, category: .wedge),
    ClubInfo(name: "GW",  fullName: "Gap Wedge",  ratio: 0.657, category: .wedge),
    ClubInfo(name: "SW",  fullName: "Sand Wedge", ratio: 0.557, category: .wedge),
    ClubInfo(name: "LW",  fullName: "Lob Wedge",  ratio: 0.464, category: .wedge),
  ]

  /// Calculate carry distance for each club given the 7-iron carry.
  static func distances(sevenIronCarry: Int) -> [(club: ClubInfo, carry: Int)] {
    clubs.map { ($0, Int(Double(sevenIronCarry) * $0.ratio)) }
  }

  /// Recommend a club for a given distance (yards).
  /// Returns the club whose carry is closest to (but not less than) the target,
  /// preferring to "club up" rather than down — better to be pin-high than short.
  static func recommend(distanceYards: Int, sevenIronCarry: Int) -> ClubInfo {
    let dists = distances(sevenIronCarry: sevenIronCarry)
    // Find the shortest club that still reaches
    if let match = dists.reversed().first(where: { $0.carry >= distanceYards }) {
      return match.club
    }
    // If nothing reaches (very long shot), recommend driver
    return clubs[0]
  }

  /// Build a human-readable club chart for the system prompt
  static func chartText(sevenIronCarry: Int) -> String {
    let dists = distances(sevenIronCarry: sevenIronCarry)
    var lines: [String] = ["GOLFER'S CLUB DISTANCES (carry, calibrated from 7-iron = \(sevenIronCarry)y):"]
    for d in dists {
      lines.append("  \(d.club.fullName): \(d.carry)y")
    }
    lines.append("Use these distances for club recommendations. Always factor in wind, elevation, and lie.")
    return lines.joined(separator: "\n")
  }
}
