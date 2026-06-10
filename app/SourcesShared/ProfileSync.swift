import Foundation
import os

/// One title's watch state inside a profile's private overlay: enough to render Continue Watching,
/// resume, and watched markers without touching the account's shared library.
struct WatchEntry: Codable, Equatable {
    var videoId: String?          // movie id, or imdbId:season:episode for the episode in progress
    var timeOffsetMs: Int
    var durationMs: Int
    var lastWatched: String       // ISO timestamp, orders the rail
    var name: String
    var type: String
    var poster: String?
    var watchedVideoIds: [String] = []

    var progress: Double {
        guard durationMs > 0 else { return 0 }
        return min(max(Double(timeOffsetMs) / Double(durationMs), 0), 1)
    }
}

/// Syncs profile data through the Stremio account's datastore, so profiles and their watch
/// history follow the account to every device running StremioX.
///
/// Storage trick: each payload lives in a `libraryItem` document with `type: "other"` and
/// `removed: true`. That combination is invisible everywhere: stremio-core excludes type "other"
/// from Continue Watching and removed items from the library views, and the official apps run the
/// same core. But the documents still sync with the account like any library item. Payloads ride
/// in custom top-level fields, which the API stores as-is; the engine never pushes back documents
/// it hasn't mutated, so the custom fields survive engine syncs.
enum ProfileSync {
    private static let api = "https://api.strem.io/api"
    private static let rosterID = "stremiox:profiles"
    private static let log = Logger(subsystem: "com.stremiox.app", category: "profilesync")

    private static func watchID(_ profileID: UUID) -> String { "stremiox:watch:\(profileID.uuidString)" }

    // MARK: Roster (profile list, synced on the PRIMARY account)

    /// The remote roster and its modification time, or nil when none was ever pushed.
    static func fetchRoster(authKey: String) async -> (profiles: [UserProfile], mtime: Date)? {
        guard let data = await fetchPayload(id: rosterID, authKey: authKey),
              let profiles = try? JSONDecoder().decode([UserProfile].self, from: data.payload),
              !profiles.isEmpty else { return nil }
        log.info("roster fetched: \(profiles.count) profiles")
        return (profiles, data.mtime)
    }

    static func pushRoster(_ profiles: [UserProfile], authKey: String) async {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        await pushPayload(data, id: rosterID, name: "StremioX Profiles", authKey: authKey)
        log.info("roster pushed: \(profiles.count) profiles")
    }

    // MARK: Watch overlay (per profile, synced on that profile's account)

    static func fetchWatch(profileID: UUID, authKey: String) async -> [String: WatchEntry]? {
        guard let data = await fetchPayload(id: watchID(profileID), authKey: authKey),
              let watch = try? JSONDecoder().decode([String: WatchEntry].self, from: data.payload) else { return nil }
        log.info("watch overlay fetched from server: \(watch.count) entries")
        return watch
    }

    static func pushWatch(_ watch: [String: WatchEntry], profileID: UUID, authKey: String) async {
        // Keep the document a sane size: the rail only ever shows recent titles anyway.
        let trimmed = watch.count <= 120 ? watch
            : Dictionary(uniqueKeysWithValues: watch.sorted { $0.value.lastWatched > $1.value.lastWatched }
                .prefix(120).map { ($0.key, $0.value) })
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        await pushPayload(data, id: watchID(profileID), name: "StremioX Profile Watch", authKey: authKey)
        log.info("watch overlay pushed: \(trimmed.count) entries")
    }

    // MARK: Payload transport
    //
    // The API normalizes libraryItem documents against its schema and STRIPS unknown fields
    // (verified live: a custom top-level field came back missing). `state.watched` is a schema
    // STRING field designed to carry long opaque per-account data (real watched bitfields run to
    // kilobytes), so the payload rides there as a JSON string and survives validation verbatim.

    private static func pushPayload(_ payload: Data, id: String, name: String, authKey: String) async {
        guard let string = String(data: payload, encoding: .utf8) else { return }
        await putItem(blobSkeleton(id: id, name: name, watched: string), authKey: authKey)
    }

    private static func fetchPayload(id: String, authKey: String) async -> (payload: Data, mtime: Date)? {
        guard let item = await fetchItem(id: id, authKey: authKey),
              let state = item["state"] as? [String: Any],
              let string = state["watched"] as? String, !string.isEmpty,
              let payload = string.data(using: .utf8) else { return nil }
        let mtime = (item["_mtime"] as? String).flatMap(parseISO) ?? .distantPast
        return (payload, mtime)
    }

    // MARK: Datastore plumbing

    /// A libraryItem document no Stremio client will ever display (type "other" + removed, never
    /// in Continue Watching or library views), used purely as synced storage.
    private static func blobSkeleton(id: String, name: String, watched: String) -> [String: Any] {
        let now = isoNow()
        return [
            "_id": id,
            "name": name,
            "type": "other",
            "posterShape": "poster",
            "removed": true,
            "temp": false,
            "_ctime": now,
            "_mtime": now,
            "state": ["lastWatched": now, "timeWatched": 0, "timeOffset": 0, "overallTimeWatched": 0,
                      "timesWatched": 0, "flaggedWatched": 0, "duration": 0, "video_id": "",
                      "watched": watched, "noNotif": true] as [String: Any],
        ]
    }

    private static func fetchItem(id: String, authKey: String) async -> [String: Any]? {
        let body: [String: Any] = ["authKey": authKey, "collection": "libraryItem", "ids": [id], "all": false]
        guard let data = try? await post("datastoreGet", body: body),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            log.error("datastoreGet \(id, privacy: .public): request failed")
            return nil
        }
        guard let result = object["result"] as? [[String: Any]], let item = result.first else {
            let raw = String(data: data, encoding: .utf8)?.prefix(300) ?? "?"
            log.info("datastoreGet \(id, privacy: .public): empty result (\(String(raw), privacy: .public))")
            return nil
        }
        log.info("datastoreGet \(id, privacy: .public): keys \(item.keys.sorted().joined(separator: ","), privacy: .public)")
        return item
    }

    private static func putItem(_ item: [String: Any], authKey: String) async {
        let body: [String: Any] = ["authKey": authKey, "collection": "libraryItem", "changes": [item]]
        guard let data = try? await post("datastorePut", body: body) else {
            log.error("datastorePut \(item["_id"] as? String ?? "?", privacy: .public): request failed")
            return
        }
        let raw = String(data: data, encoding: .utf8)?.prefix(200) ?? "?"
        log.info("datastorePut \(item["_id"] as? String ?? "?", privacy: .public): \(String(raw), privacy: .public)")
    }

    private static func post(_ path: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: URL(string: "\(api)/\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    private static func isoNow() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private static func parseISO(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: string)
        }()
    }
}
