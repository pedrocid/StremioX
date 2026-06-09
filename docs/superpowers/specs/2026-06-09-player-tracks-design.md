# Player Core, Part 1: Smart Tracks and Instant Switching

**Goal:** the player picks the right audio and subtitle track automatically from your preferences, lets you override and have it remembered, and switches tracks instantly without restarting the stream.

**Scope:** Apple TV first, built in the shared player layer (`app/Sources/Player/`) so the coming iOS/iPad client reuses it. Two features, one epic. Skip intro/outro, auto-recovery, and the in-player stream switcher are a separate later epic.

This is the first build of v1.0 (see `wiki/projects/stremiox/v1-plan.md`). Engine and add-ons are untouched; this is all client-side.

## Feature A: smart track auto-selection

When a title starts, the player should choose the audio and subtitle track a person would have chosen, from their stated preferences, instead of leaving whatever the file defaults to.

**Components**

- **`TrackPreferences`** (shared, `Codable`, persisted in `UserDefaults`): ordered preferred audio languages, ordered preferred subtitle languages, a forced-subtitle policy (`auto` / `always` / `off`), and reject lists (language codes or title substrings that must never be auto-picked, e.g. "commentary", "SDH" when unwanted).
- **`TrackSelector`** (shared, a pure function): given the mpv track list (`[MPVTrack]`, which already carries `id`, `lang`, `title`, `selected`), the `TrackPreferences`, and the title context, returns the audio track id and subtitle track id to select. No side effects, so it is unit-testable in isolation. This is the heart of the feature and where the language-matching and forced-subtitle rules live.
- **Per-show memory** (shared): when the user manually changes a track during playback, record `{audioLang, subLang or off}` keyed by the series id (or binge-group), and let `TrackSelector` prefer that remembered choice over the global defaults for that show.
- **Player integration** (`TVPlayerView` / shared coordinator): on the `trackList` property event, run `TrackSelector` and apply via the existing `setAudioTrack` / `setSubtitleTrack`. On a manual change, write the per-show memory.
- **Settings UI** (tvOS Settings → a new Playback section): edit the preferred-language orders, the forced-subtitle policy, and the reject lists. iOS gets its own UI later; the model and selector are shared.

**Rules (TrackSelector)**

- Audio: first track whose language matches the preferred order; else the file default; never a rejected track.
- Subtitle: if a preferred audio language was matched and equals the content's primary language, subtitles default off unless the policy says `always` or a forced track exists; otherwise the first preferred-language subtitle. Forced subtitles follow the policy.
- A remembered per-show choice overrides the above for that show.

## Feature B: instant track switching

Today, switching audio or subtitle mid-playback feels like the stream restarts (the stated pain). mpv changes `aid`/`sid` instantly for tracks already demuxed, so the first task is to find why it stalls here. Likely causes, in order of suspicion: external subtitles from add-ons are fetched on select rather than preloaded; the demux cache is too small so a switch re-demuxes; or an HLS/remuxed debrid stream needs a different variant. 

**Approach**

- Confirm the switch path sets the mpv property (`aid` / `sid`) directly and never calls `loadFile`.
- Preload embedded tracks and add external subtitles with mpv `sub-add` ahead of selection (not on the click), so selecting is instant.
- Size the demux cache so all tracks stay in memory across a switch.
- Verify on a real multi-audio, multi-subtitle release that switching does not re-buffer.

## Data flow

`trackList` event → `TrackSelector(prefs, context)` → apply selection. Manual change → apply + persist per-show memory. Settings edits → update `TrackPreferences` → take effect on the next title (and re-run for the current one).

## Error handling and edge cases

- No preferred-language match: fall back to the file default audio, subtitles off (unless `always` or forced).
- Empty or single-track files: no-op.
- A remembered language no longer present: fall back to the global rules.
- Reject list must never strand the user with no audio: if every audio track is rejected, pick the default and surface nothing (rejects are for auto-pick only, not a hard ban).

## Testing

- **Unit:** `TrackSelector` with parameterized track lists and preferences (preferred match, no match, forced-on, forced-off, reject filtering, per-show override). This is the bulk of the coverage and needs no device.
- **Manual / sim:** auto-select fires on play; a manual change persists and is reused next episode; switching tracks does not re-buffer (the instant-switching check) on a real multi-track release.

## Files

- Create: `app/Sources/Player/TrackPreferences.swift`, `app/Sources/Player/TrackSelector.swift`, `app/Sources/Player/ShowTrackMemory.swift`, tests under `app/Tests/`.
- Modify: `app/Sources/Player/MPVMetalViewController.swift` (preload tracks, cache sizing, confirm property-set switching), `app/SourcesTV/TVPlayerView.swift` (run the selector on `trackList`, record manual changes), `app/SourcesTV/SettingsView.swift` (Playback preferences UI).

## Out of scope (next epic)

Skip intro/outro + auto next-episode, player auto-recovery, and the in-player stream switcher. They share the player but are independent work.
