# Hiking

A native macOS SwiftUI app for tracking and exploring 8+ years of hiking data. Supports two hikers with individual trail preferences, based in West Seattle.

No Xcode required — builds with just the Swift command-line tools.

## Features

### Dashboard
- Stats cards: total hikes, miles, elevation, averages — filterable by year and region
- Monthly and yearly activity bar charts (Swift Charts)
- Top 15 most-hiked trails table — double-click any trail to see full history with stats and a distance-over-time chart

### Map
- Full MapKit view with trail pins colored by region, sized by visit count
- Preset view buttons: All Washington, Western WA, I-90 Corridor, Snoqualmie, Seattle Metro, North Cascades, Olympics
- Click a pin to see trail details, visit history, and averages in the sidebar

### Hike Log
- Sortable, filterable table of all hikes with year/region/search filters
- **Double-click** a hike to see a detail popover with:
  - Map header showing trailhead location
  - Stats: distance, elevation, duration, pace, altitude range
  - Photos from that day pulled from your Photos library (filtered by GPS proximity)
  - Trail link (AllTrails/WTA) if available
  - This-hike-vs-average comparison bars
  - Full visit history with chart
  - Trail info (difficulty, dog-friendly, description)
  - Coordinates with "Open in Maps" button
- **Photos button** on each row to view photos from that hike day
- **Edit** any hike — change trail association, date, distance, elevation, duration, coordinates
- When re-associating a hike's trail, a dialog shows all other hikes on the same old trail with GPS distance, letting you select which ones to also update
- **Add** hikes manually or **delete** from context menu

### Trails
- **Hiked / Want to Do** segmented view — trails are automatically categorized based on whether any hike is logged against them
- Add trails from **AllTrails or WTA URLs** — fetches the page and extracts name, region, coordinates, distance, elevation, difficulty
- Add trails manually or edit any field
- **Heart columns** for both hikers to mark loved trails
- **Double-click** a trail to see all hikes with summary stats
- Open trail URLs in browser, edit, or delete
- Search by name or region

### Data Import/Export
- **File > Import Health Auto Export (.zip)** — parses Apple Health workout exports (route CSVs for coordinates/altitude/duration, distance, flights climbed), matches to trail database by GPS proximity
- **File > Import Hike History (.json)** — merge additional hike data
- **File > Export Hike History** — save all data as JSON
- **File > Reveal Data in Finder** — open the data directory

### Photos Integration
- Photos from your Apple Photos library are shown inline, filtered by date AND GPS proximity to the hike location (5-mile radius)
- Available in both the hike detail popover and as a standalone popover from the log table
- Double-click any photo to open it in Preview
- Requires Photos permission (prompted on first use)

## Data Storage

All data persists to `~/Library/Application Support/Hiking/`:
- `hike_history.json` — all hikes with date, distance, elevation, duration, coordinates, trail links
- `trails.json` — trail database with names, regions, URLs, coordinates, loved-by flags, difficulty, dog-friendly

On first launch, the app seeds from bundled data. After that, all changes are saved to Application Support, which survives app updates.

## Build & Install

Requires macOS 14+ and Swift command-line tools (no Xcode needed).

```bash
# Build and run (debug)
cd HikingLog
swift build
.build/debug/Hiking

# Build release and install to /Applications
cd HikingLog
./install.sh
```

The install script builds a release binary, creates a proper `.app` bundle in `/Applications` with Info.plist and app icon, and registers it with Launch Services.

## Multi-Mac Sync (iCloud)

Data syncs across Macs via iCloud Drive. The actual files live in iCloud and each Mac symlinks to them.

### First Mac (already done)

```bash
# Move data to iCloud Drive
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/Hiking
mv ~/Library/Application\ Support/Hiking/hike_history.json ~/Library/Mobile\ Documents/com~apple~CloudDocs/Hiking/
mv ~/Library/Application\ Support/Hiking/trails.json ~/Library/Mobile\ Documents/com~apple~CloudDocs/Hiking/

# Symlink back
ln -sf ~/Library/Mobile\ Documents/com~apple~CloudDocs/Hiking/hike_history.json ~/Library/Application\ Support/Hiking/hike_history.json
ln -sf ~/Library/Mobile\ Documents/com~apple~CloudDocs/Hiking/trails.json ~/Library/Application\ Support/Hiking/trails.json
ln -sf ~/Library/Mobile\ Documents/com~apple~CloudDocs/Hiking/recommendations.json ~/Library/Application\ Support/Hiking/recommendations.json
```

### Additional Macs

```bash
# Create local app directory
mkdir -p ~/Library/Application\ Support/Hiking

# Symlink to iCloud data (already synced)
ln -sf ~/Library/Mobile\ Documents/com~apple~CloudDocs/Hiking/hike_history.json ~/Library/Application\ Support/Hiking/hike_history.json
ln -sf ~/Library/Mobile\ Documents/com~apple~CloudDocs/Hiking/trails.json ~/Library/Application\ Support/Hiking/trails.json
ln -sf ~/Library/Mobile\ Documents/com~apple~CloudDocs/Hiking/recommendations.json ~/Library/Application\ Support/Hiking/recommendations.json
```

Then build and install the app (`cd HikingLog && ./install.sh`).

**Note:** The API key (`.api_key`) is kept local per machine — enter it separately on each Mac via the Recommendations settings.

## MCP Server

An MCP (Model Context Protocol) server exposes the hiking data to Claude for analysis and recommendations.

### Tools

| Tool | Description |
|------|-------------|
| `get_hike_stats` | Overall statistics, filterable by year/region |
| `get_trail_history` | All hikes for a trail with stats, URLs, coordinates |
| `search_trails` | Search by name, region, loved-by, wishlist, distance, difficulty, dog-friendly |
| `find_trails_near` | Find trails within N miles of a point or another trail |
| `get_hiking_patterns` | Frequency, seasonal trends, day-of-week, progression analysis |
| `get_recommendations` | Personalized recommendations based on preferences, loved trails, drive distance |
| `get_all_regions` | All regions with trail and hike counts |

### Claude Desktop (Desktop Extension)

Build the `.mcpb` bundle:

```bash
cd mcp-server
npm install
npx @anthropic-ai/mcpb pack . ../hiking-data.mcpb
```

Then double-click `hiking-data.mcpb` to install in Claude Desktop.

### Claude Code

The `.mcp.json` in the project root auto-configures the server for Claude Code sessions:

```bash
cd /path/to/hiking-log
claude  # MCP server is available automatically
```

## Project Structure

```
hiking-log/
  CLAUDE.md                     # Context for Claude (MCP tools, recommendations guidance)
  README.md                     # This file
  .mcp.json                     # MCP server config for Claude Code
  data/
    DATA_FORMAT.md              # Data schema documentation
    hike_history.json           # Symlink to live data (gitignored)
    trails.json                 # Symlink to live data (gitignored)
  HikingLog/
    Package.swift               # Swift Package Manager config
    install.sh                  # Build + install to /Applications
    HikingLog/
      HikingLogApp.swift        # App entry point, menus, import/export, drag-and-drop
      ContentView.swift         # Sidebar navigation
      Models/
        Hike.swift              # Hike data model (with partner, trail linking)
        HikeStore.swift         # Hike persistence, CRUD, streaks, PRs, year-over-year
        Trail.swift             # Trail data model (notes, tags, loved-by, wishlist)
        TrailStore.swift        # Trail persistence, CRUD, URL import (AllTrails/WTA)
        HealthAutoExportImporter.swift  # Apple Health export zip parser
        WeatherService.swift    # Open-Meteo weather forecast integration
        ClaudeService.swift     # Anthropic API client for recommendations
      Views/
        DashboardView.swift     # Stats, streaks, PRs, YoY, seasonal, charts, top trails
        HikeMapView.swift       # MapKit view with trail pins, dark/light mode
        HikeLogView.swift       # Hike table, editor, trail picker, bulk update, partner toggle
        HikeDetailView.swift    # Detail popover (stats, photos, history, comparison)
        HikePhotosView.swift    # Photos library integration (PhotoKit)
        TrailsView.swift        # Trail management, URL import, hearts, wishlist, weather
        YearInReviewView.swift  # Per-year summary with charts, map, stats
        RecommendationsView.swift  # Claude-powered trail recommendations
      Resources/
        hike_history.json       # Bundled hike data (seed)
        trail_database.json     # Bundled trail database (seed)
        AppIcon.icns            # App icon
  mcp-server/
    server.mjs                  # MCP server (Node.js)
    manifest.json               # Desktop Extension manifest
    package.json
```
