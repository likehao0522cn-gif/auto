import Combine
import Foundation
import TuneCore

/// Stores the user's favorite tempos and tracks how much each tempo is used.
///
/// The visible list and the usage statistics are deliberately separate:
/// a tempo that has merely been played a few times must not appear in the
/// list until the user adds it or the automatic rule promotes it.
@MainActor
final class FavoriteTempoStore: ObservableObject {
    /// The visible list, always kept in ascending order internally.
    @Published private(set) var tempos: [FavoriteTempo] = []

    @Published var sortOrder: FavoriteTempoSort {
        didSet { defaults.set(sortOrder.rawValue, forKey: Keys.sortOrder) }
    }

    /// When enabled, heavily used tempos are added without being asked.
    @Published var autoAddEnabled: Bool {
        didSet { defaults.set(autoAddEnabled, forKey: Keys.autoAdd) }
    }

    private let defaults: UserDefaults
    /// Usage counters for every tempo the user has played, favorites or not.
    private var stats: [Int: FavoriteTempo] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.sortOrder = FavoriteTempoSort(
            rawValue: defaults.string(forKey: Keys.sortOrder) ?? ""
        ) ?? .speedAscending
        self.autoAddEnabled = defaults.object(forKey: Keys.autoAdd) as? Bool ?? false
        load()
    }

    var sortedTempos: [FavoriteTempo] {
        FavoriteTempoRules.sorted(tempos, by: sortOrder)
    }

    var isFull: Bool { tempos.count >= FavoriteTempoRules.capacity }

    func contains(bpm: Int) -> Bool {
        tempos.contains { $0.bpm == bpm }
    }

    // MARK: - Manual edits

    /// Returns false when the list is full, so the caller can tell the user.
    @discardableResult
    func add(bpm: Int, isManual: Bool = true) -> Bool {
        let rounded = Int(MetronomeTempo.clampedBPM(Double(bpm)))
        guard !contains(bpm: rounded) else { return true }
        guard !isFull else { return false }
        var entry = stats[rounded] ?? FavoriteTempo(bpm: rounded)
        entry.isManual = isManual
        stats[rounded] = entry
        tempos.append(entry)
        save()
        return true
    }

    /// Removes a tempo from the list and clears its statistics, so the
    /// automatic rule cannot immediately add it back.
    func remove(bpm: Int) {
        tempos.removeAll { $0.bpm == bpm }
        stats[bpm] = nil
        save()
    }

    // MARK: - Usage statistics

    /// Records that playback started at this tempo.
    func recordStart(bpm: Int) {
        let rounded = Int(MetronomeTempo.clampedBPM(Double(bpm)))
        var entry = stats[rounded] ?? FavoriteTempo(bpm: rounded, isManual: false)
        entry.useCount += 1
        stats[rounded] = entry
        applyAutomaticPromotionIfNeeded(for: rounded)
        syncVisibleEntry(for: rounded)
        save()
    }

    /// Records elapsed playback time. Called periodically while playing, so it
    /// only persists when the value actually changed the visible list.
    func recordPlayback(bpm: Int, seconds: Double) {
        guard seconds > 0 else { return }
        let rounded = Int(MetronomeTempo.clampedBPM(Double(bpm)))
        var entry = stats[rounded] ?? FavoriteTempo(bpm: rounded, isManual: false)
        entry.totalPlaySeconds += seconds
        stats[rounded] = entry
        let countBefore = tempos.count
        applyAutomaticPromotionIfNeeded(for: rounded)
        syncVisibleEntry(for: rounded)
        // Play time accumulates constantly; persist only when it matters.
        if tempos.count != countBefore {
            save()
        } else {
            persistStatsOnly()
        }
    }

    /// Promotes a tempo once it has been used enough, if the user allowed it.
    private func applyAutomaticPromotionIfNeeded(for bpm: Int) {
        guard autoAddEnabled,
              !contains(bpm: bpm),
              !isFull,
              let entry = stats[bpm],
              FavoriteTempoRules.qualifiesForAutomaticAdd(entry) else {
            return
        }
        var promoted = entry
        promoted.isManual = false
        tempos.append(promoted)
    }

    /// Copies fresh statistics onto the visible entry so the list shows
    /// accurate counts and times.
    private func syncVisibleEntry(for bpm: Int) {
        guard let updated = stats[bpm],
              let index = tempos.firstIndex(where: { $0.bpm == bpm }) else { return }
        var merged = updated
        merged.isManual = tempos[index].isManual
        tempos[index] = merged
    }

    // MARK: - Persistence

    private func load() {
        if let data = defaults.data(forKey: Keys.stats),
           let decoded = try? JSONDecoder().decode([Int: FavoriteTempo].self, from: data) {
            stats = decoded
        }
        if let data = defaults.data(forKey: Keys.list),
           let decoded = try? JSONDecoder().decode([FavoriteTempo].self, from: data) {
            tempos = decoded
        }
    }

    /// Writes only the statistics, leaving the visible list untouched.
    private func persistStatsOnly() {
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: Keys.stats)
        }
    }

    private func save() {
        tempos.sort { $0.bpm < $1.bpm }
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: Keys.stats)
        }
        if let data = try? JSONEncoder().encode(tempos) {
            defaults.set(data, forKey: Keys.list)
        }
    }

    private enum Keys {
        static let stats = "favoriteTempo.stats"
        static let list = "favoriteTempo.list"
        static let sortOrder = "favoriteTempo.sortOrder"
        static let autoAdd = "favoriteTempo.autoAdd"
    }
}
