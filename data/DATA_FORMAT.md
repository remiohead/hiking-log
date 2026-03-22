# Hiking Data Format

These files are **live symlinks** to `~/Library/Application Support/Hiking/` and reflect the current state of the Hiking app. They update whenever the app saves.

## Context

This is hiking data for two hikers. The home location and persona names are configured in `~/Library/Application Support/Hiking/.config`. Drive distance from the home location is relevant when making recommendations.

---

## hike_history.json

An array of hike records, one per hiking session. 239 hikes as of March 2026.

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique ID, format `YYYYMMDD_HHMMSS` from the workout start time |
| `date` | string | Hike date, `YYYY-MM-DD` |
| `trail_name` | string | Name of the trail |
| `region` | string | Geographic region (e.g. "Alpine Lakes", "I-90 Corridor", "Seattle Urban") |
| `trail_id` | string or null | Links to a trail in `trails.json` by `id`. Null if not linked. |
| `distance_miles` | number | Total distance hiked in miles |
| `elevation_gain_ft` | number | Elevation gain in feet |
| `duration_minutes` | integer | Duration in minutes |
| `start_lat` | number | Start latitude (GPS) |
| `start_lon` | number | Start longitude (GPS) |
| `end_lat` | number | End latitude (GPS) |
| `end_lon` | number | End longitude (GPS) |
| `min_altitude_ft` | number | Minimum altitude reached in feet |
| `max_altitude_ft` | number | Maximum altitude reached in feet |
| `match_confidence` | string | How confidently the trail was auto-matched: "high", "medium", "low", "none", or "manual" |
| `distance_to_trailhead_miles` | number | Distance from GPS start to the matched trailhead |

### Notes
- Hikes are sorted newest-first.
- The `trail_id` field links to `trails.json`. When present, the trail's name, region, and URL provide additional context.
- `match_confidence` reflects automated matching from GPS coordinates. Many trails have been manually corrected by the user.
- GPS coordinates are from Apple Watch workout data (Health Auto Export).

---

## trails.json

An array of trail records — the user's trail database. 93 trails as of March 2026. Includes both trails that have been hiked and trails on the "Want to Do" wishlist (no hikes logged).

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | UUID |
| `name` | string | Trail name |
| `region` | string | Geographic region |
| `url` | string or null | AllTrails or WTA page URL |
| `trailheadLat` | number | Trailhead latitude |
| `trailheadLon` | number | Trailhead longitude |
| `distanceMiles` | number or null | Trail distance in miles |
| `elevationGainFt` | number or null | Elevation gain in feet |
| `difficulty` | string or null | "easy", "moderate", or "hard" |
| `dogFriendly` | boolean or null | Whether dogs are allowed |
| `dogNotes` | string or null | Dog-specific notes |
| `trailDescription` | string or null | Description of the trail |
| `source` | string or null | How the trail was added: "alltrails", "wta", "manual", or "imported" |
| `lovedByShaun` | boolean or null | Whether person 1 has marked this as a favorite |
| `lovedByJulie` | boolean or null | Whether person 2 has marked this as a favorite |
| `isWishlist` | boolean or null | Explicitly marked as wishlist (also inferred: trails with no hikes are wishlist) |

### Notes
- A trail is considered **"hiked"** if any hike in `hike_history.json` has a matching `trail_id` or `trail_name`.
- A trail is considered **"wishlist"** if no hikes are logged against it — these are trails the user wants to do.
- The `url` field links to the AllTrails or WTA page for the trail when available.
- The `lovedByShaun`/`lovedByJulie` fields indicate personal favorites for each hiker — strong preference signals for recommendations. (Field names are fixed for data compatibility; display names are configurable.)
- Coordinates are the trailhead location and can be used to calculate drive distances or find nearby trails.

---

## Regions

The main hiking regions in the data:

- **Alpine Lakes** — Popular backcountry area along I-90 and US-2
- **Snoqualmie Pass** — Trails near the pass, ~55 miles from Seattle
- **I-90 Corridor** — Trails along the I-90 highway
- **Seattle Urban** — City parks and urban trails
- **West Seattle** — Local trails near home
- **North Cascades** — Remote trails in the northern mountains
- **Olympic Peninsula** — Trails on the Olympic Peninsula
- **Mount Rainier** — Trails in/near Mount Rainier National Park
- **Index/Stevens Pass** — Trails along US-2 corridor
- **Issaquah/Tiger Mountain** — Eastside foothills
- **Cascade Foothills** — Lower elevation Cascade trails
- **San Juan Islands** — Island trails accessible by ferry

---

## Useful Queries

**Find most-hiked trails:** Group `hike_history.json` by `trail_name`, count, and sort descending.

**Find wishlist trails:** Trails in `trails.json` with no matching hikes in `hike_history.json`.

**Seasonal patterns:** Group hikes by month (`date` field, characters 5-7) to see which months are most active.

**Calculate drive distance:** Use the haversine formula from the home location (configured in `.config`) to `trailheadLat`/`trailheadLon`. Multiply by ~1.3 for road distance approximation.

**Find trails near each other:** Compare `trailheadLat`/`trailheadLon` between trails using haversine distance.

**Recommendations:** Prioritize loved trails, similar regions to frequently hiked ones, appropriate distance/elevation ranges, and reasonable drive distances.
