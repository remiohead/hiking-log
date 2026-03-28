# Hiking Log

A native macOS SwiftUI app tracking 8+ years of hiking data for two hikers with configurable home location. All personal settings (names, home coordinates, API key, email) are in `~/Library/Application Support/Hiking/.config`.

## Data Access

Both the app and MCP server check iCloud Drive first (`~/Library/Mobile Documents/com~apple~CloudDocs/Hiking/`), falling back to `~/Library/Application Support/Hiking/`. Machine-specific config (API key, email) always stays in Application Support.

- `hike_history.json` — All hikes (date, distance, elevation, duration, GPS coordinates, trail links)
- `trails.json` — Trail database (names, regions, URLs, coordinates, loved-by flags, difficulty, dog-friendly)

An MCP server is also available (see `mcp-server-swift/`) with tools for stats, search, recommendations, and pattern analysis.

## Key Context for Recommendations

- The hikers' home location is configured in the app settings. Drive distance matters.
- Trails have "loved" flags for each person — use these as preference signals.
- Trails with no hikes logged are the wishlist ("Want to Do").
- The trail URL field links to AllTrails or WTA pages with more detail.
- Dog-friendly trails are flagged — they sometimes hike with their dog.

## Build

```bash
cd HikingLog && swift build && .build/debug/Hiking
# Or install to /Applications:
cd HikingLog && ./install.sh
```
