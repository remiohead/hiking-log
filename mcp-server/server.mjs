import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";

// Data paths
const DATA_DIR = join(homedir(), "Library", "Application Support", "Hiking");
const HIKES_FILE = join(DATA_DIR, "hike_history.json");
const CONFIG_FILE = join(DATA_DIR, ".config");

function loadConfig() {
  if (!existsSync(CONFIG_FILE)) return { person1: "Person 1", person2: "Person 2", homeName: "Home", homeLat: 47.5, homeLon: -121.8 };
  const lines = readFileSync(CONFIG_FILE, "utf-8").split("\n").map(l => l.trim());
  return {
    person1: lines[0] || "Person 1",
    person2: lines[1] || "Person 2",
    homeName: lines[2] || "Home",
    homeLat: parseFloat(lines[3]) || 47.5,
    homeLon: parseFloat(lines[4]) || -121.8,
  };
}
const TRAILS_FILE = join(DATA_DIR, "trails.json");

function loadJSON(path) {
  if (!existsSync(path)) return [];
  return JSON.parse(readFileSync(path, "utf-8"));
}

function loadHikes() { return loadJSON(HIKES_FILE); }
function loadTrails() { return loadJSON(TRAILS_FILE); }

function haversineDistanceMiles(lat1, lon1, lat2, lon2) {
  const R = 3958.8;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Create server
const server = new McpServer({
  name: "hiking",
  version: "1.0.0",
});

// --- Resources ---

server.resource("hikes", "hiking://hikes", async () => {
  const hikes = loadHikes();
  return {
    contents: [{
      uri: "hiking://hikes",
      mimeType: "application/json",
      text: JSON.stringify(hikes, null, 2),
    }],
  };
});

server.resource("trails", "hiking://trails", async () => {
  const trails = loadTrails();
  return {
    contents: [{
      uri: "hiking://trails",
      mimeType: "application/json",
      text: JSON.stringify(trails, null, 2),
    }],
  };
});

// --- Tools ---

server.tool(
  "get_hike_stats",
  "Get overall hiking statistics, optionally filtered by year or region",
  {
    year: z.string().optional().describe("Filter by year (e.g. '2024')"),
    month: z.string().optional().describe("Filter by month (e.g. '10' for October). Combine with year for a specific month."),
    region: z.string().optional().describe("Filter by region"),
  },
  async ({ year, month, region }) => {
    let hikes = loadHikes();
    if (year) hikes = hikes.filter(h => h.date.startsWith(year));
    if (month) { const m = month.padStart(2, "0"); hikes = hikes.filter(h => h.date.slice(5, 7) === m); }
    if (region) hikes = hikes.filter(h => h.region === region);
    const n = hikes.length || 1;
    const totalMiles = hikes.reduce((a, h) => a + h.distance_miles, 0);
    const totalElevation = hikes.reduce((a, h) => a + h.elevation_gain_ft, 0);
    const totalMinutes = hikes.reduce((a, h) => a + h.duration_minutes, 0);
    const uniqueTrails = [...new Set(hikes.map(h => h.trail_name))].length;
    const regions = [...new Set(hikes.map(h => h.region))];
    const years = [...new Set(hikes.map(h => h.date.slice(0, 4)))].sort();

    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          total_hikes: hikes.length,
          unique_trails: uniqueTrails,
          total_miles: Math.round(totalMiles * 10) / 10,
          total_elevation_ft: Math.round(totalElevation),
          total_duration_hours: Math.round(totalMinutes / 60 * 10) / 10,
          avg_miles: Math.round(totalMiles / n * 10) / 10,
          avg_elevation_ft: Math.round(totalElevation / n),
          avg_duration_minutes: Math.round(totalMinutes / n),
          regions,
          years,
          date_range: hikes.length ? { first: hikes[hikes.length - 1].date, last: hikes[0].date } : null,
        }, null, 2),
      }],
    };
  }
);

server.tool(
  "get_trail_history",
  "Get all hikes for a specific trail, with stats",
  {
    trail_name: z.string().describe("Trail name to look up"),
  },
  async ({ trail_name }) => {
    const hikes = loadHikes().filter(h =>
      h.trail_name.toLowerCase().includes(trail_name.toLowerCase())
    );
    const trails = loadTrails().filter(t =>
      t.name.toLowerCase().includes(trail_name.toLowerCase())
    );
    const trail = trails[0];
    const n = hikes.length || 1;

    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          trail_name: hikes[0]?.trail_name || trail_name,
          region: hikes[0]?.region || trail?.region || "Unknown",
          trail_info: trail ? {
            url: trail.url,
            distance_miles: trail.distanceMiles,
            elevation_gain_ft: trail.elevationGainFt,
            difficulty: trail.difficulty,
            dog_friendly: trail.dogFriendly,
            loved_by_shaun: trail.lovedByShaun,
            loved_by_julie: trail.lovedByJulie,
            coordinates: { lat: trail.trailheadLat, lon: trail.trailheadLon },
          } : null,
          total_visits: hikes.length,
          avg_miles: Math.round(hikes.reduce((a, h) => a + h.distance_miles, 0) / n * 10) / 10,
          avg_elevation_ft: Math.round(hikes.reduce((a, h) => a + h.elevation_gain_ft, 0) / n),
          avg_duration_minutes: Math.round(hikes.reduce((a, h) => a + h.duration_minutes, 0) / n),
          hikes: hikes.map(h => ({
            date: h.date,
            distance_miles: h.distance_miles,
            elevation_gain_ft: h.elevation_gain_ft,
            duration_minutes: h.duration_minutes,
          })),
        }, null, 2),
      }],
    };
  }
);

server.tool(
  "search_trails",
  "Search trails by name, region, or attributes",
  {
    query: z.string().optional().describe("Search by name"),
    region: z.string().optional().describe("Filter by region"),
    loved_by: z.enum(["shaun", "julie", "both", "either"]).optional().describe("Filter by who loved the trail"),
    is_wishlist: z.boolean().optional().describe("True for un-hiked trails, false for hiked"),
    max_distance_miles: z.number().optional().describe("Max trail distance in miles"),
    min_distance_miles: z.number().optional().describe("Min trail distance in miles"),
    difficulty: z.string().optional().describe("Filter by difficulty: easy, moderate, hard"),
    dog_friendly: z.boolean().optional().describe("Filter by dog-friendliness"),
  },
  async ({ query, region, loved_by, is_wishlist, max_distance_miles, min_distance_miles, difficulty, dog_friendly }) => {
    let trails = loadTrails();
    const hikes = loadHikes();
    const hikedNames = new Set(hikes.map(h => h.trail_name));
    const hikedIDs = new Set(hikes.filter(h => h.trail_id).map(h => h.trail_id));

    if (query) {
      const q = query.toLowerCase();
      trails = trails.filter(t => t.name.toLowerCase().includes(q) || (t.region || "").toLowerCase().includes(q));
    }
    if (region) trails = trails.filter(t => t.region === region);
    if (difficulty) trails = trails.filter(t => t.difficulty === difficulty);
    if (dog_friendly !== undefined) trails = trails.filter(t => t.dogFriendly === dog_friendly);
    if (max_distance_miles) trails = trails.filter(t => t.distanceMiles && t.distanceMiles <= max_distance_miles);
    if (min_distance_miles) trails = trails.filter(t => t.distanceMiles && t.distanceMiles >= min_distance_miles);
    if (loved_by === "shaun") trails = trails.filter(t => t.lovedByShaun);
    if (loved_by === "julie") trails = trails.filter(t => t.lovedByJulie);
    if (loved_by === "both") trails = trails.filter(t => t.lovedByShaun && t.lovedByJulie);
    if (loved_by === "either") trails = trails.filter(t => t.lovedByShaun || t.lovedByJulie);
    if (is_wishlist === true) trails = trails.filter(t => !hikedNames.has(t.name) && !hikedIDs.has(t.id));
    if (is_wishlist === false) trails = trails.filter(t => hikedNames.has(t.name) || hikedIDs.has(t.id));

    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          count: trails.length,
          trails: trails.map(t => ({
            name: t.name,
            region: t.region,
            url: t.url || null,
            distance_miles: t.distanceMiles || null,
            elevation_gain_ft: t.elevationGainFt || null,
            difficulty: t.difficulty || null,
            dog_friendly: t.dogFriendly || null,
            loved_by_shaun: t.lovedByShaun || false,
            loved_by_julie: t.lovedByJulie || false,
            is_wishlist: !hikedNames.has(t.name) && !hikedIDs.has(t.id),
            coordinates: { lat: t.trailheadLat, lon: t.trailheadLon },
            hike_count: hikes.filter(h => h.trail_name === t.name || h.trail_id === t.id).length,
          })),
        }, null, 2),
      }],
    };
  }
);

server.tool(
  "find_trails_near",
  "Find trails near a coordinate or another trail",
  {
    lat: z.number().optional().describe("Latitude"),
    lon: z.number().optional().describe("Longitude"),
    near_trail: z.string().optional().describe("Find trails near this trail name"),
    radius_miles: z.number().default(15).describe("Search radius in miles"),
  },
  async ({ lat, lon, near_trail, radius_miles }) => {
    const trails = loadTrails();

    if (near_trail && (!lat || !lon)) {
      const ref = trails.find(t => t.name.toLowerCase().includes(near_trail.toLowerCase()));
      if (ref) { lat = ref.trailheadLat; lon = ref.trailheadLon; }
    }
    if (!lat || !lon) {
      return { content: [{ type: "text", text: "Please provide coordinates or a trail name" }] };
    }

    const hikes = loadHikes();
    const nearby = trails
      .map(t => ({
        name: t.name,
        region: t.region,
        distance_from_point_miles: Math.round(haversineDistanceMiles(lat, lon, t.trailheadLat, t.trailheadLon) * 100) / 100,
        trail_distance_miles: t.distanceMiles,
        elevation_gain_ft: t.elevationGainFt,
        difficulty: t.difficulty,
        url: t.url,
        dog_friendly: t.dogFriendly,
        loved_by_shaun: t.lovedByShaun || false,
        loved_by_julie: t.lovedByJulie || false,
        coordinates: { lat: t.trailheadLat, lon: t.trailheadLon },
        hike_count: hikes.filter(h => h.trail_name === t.name || h.trail_id === t.id).length,
      }))
      .filter(t => t.distance_from_point_miles <= radius_miles)
      .sort((a, b) => a.distance_from_point_miles - b.distance_from_point_miles);

    return {
      content: [{
        type: "text",
        text: JSON.stringify({ center: { lat, lon }, radius_miles, count: nearby.length, trails: nearby }, null, 2),
      }],
    };
  }
);

server.tool(
  "get_hiking_patterns",
  "Analyze hiking patterns — frequency, seasonal trends, progression over time",
  {
    trail_name: z.string().optional().describe("Analyze patterns for a specific trail"),
  },
  async ({ trail_name }) => {
    let hikes = loadHikes();
    if (trail_name) {
      hikes = hikes.filter(h => h.trail_name.toLowerCase().includes(trail_name.toLowerCase()));
    }

    // Monthly frequency
    const monthly = {};
    hikes.forEach(h => {
      const m = h.date.slice(5, 7);
      monthly[m] = (monthly[m] || 0) + 1;
    });

    // Yearly stats
    const yearly = {};
    hikes.forEach(h => {
      const y = h.date.slice(0, 4);
      if (!yearly[y]) yearly[y] = { count: 0, miles: 0, elevation: 0 };
      yearly[y].count++;
      yearly[y].miles += h.distance_miles;
      yearly[y].elevation += h.elevation_gain_ft;
    });

    // Most frequent trails
    const trailCounts = {};
    hikes.forEach(h => { trailCounts[h.trail_name] = (trailCounts[h.trail_name] || 0) + 1; });
    const topTrails = Object.entries(trailCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([name, count]) => ({ name, count }));

    // Day of week distribution
    const dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    const dayOfWeek = {};
    hikes.forEach(h => {
      const d = dayNames[new Date(h.date + "T12:00:00").getDay()];
      dayOfWeek[d] = (dayOfWeek[d] || 0) + 1;
    });

    // Month names
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const monthlyNamed = {};
    Object.entries(monthly).forEach(([m, c]) => { monthlyNamed[monthNames[parseInt(m) - 1]] = c; });

    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          total_hikes: hikes.length,
          monthly_distribution: monthlyNamed,
          yearly_stats: yearly,
          day_of_week: dayOfWeek,
          top_trails: topTrails,
          longest_hike: hikes.reduce((best, h) => h.distance_miles > (best?.distance_miles || 0) ? h : best, null),
          most_elevation: hikes.reduce((best, h) => h.elevation_gain_ft > (best?.elevation_gain_ft || 0) ? h : best, null),
        }, null, 2),
      }],
    };
  }
);

server.tool(
  "get_recommendations",
  "Get trail recommendations based on preferences and history",
  {
    for_person: z.enum(["shaun", "julie", "both"]).optional().describe("Who is the recommendation for"),
    max_distance_miles: z.number().optional().describe("Max trail distance"),
    min_distance_miles: z.number().optional().describe("Min trail distance"),
    max_drive_miles: z.number().optional().describe("Max drive distance from home location"),
    difficulty: z.string().optional().describe("Preferred difficulty"),
    dog_friendly: z.boolean().optional().describe("Must be dog-friendly"),
    include_wishlist: z.boolean().default(true).describe("Include un-hiked trails from wishlist"),
    include_hiked: z.boolean().default(true).describe("Include previously hiked trails"),
  },
  async ({ for_person, max_distance_miles, min_distance_miles, max_drive_miles, difficulty, dog_friendly, include_wishlist, include_hiked }) => {
    let trails = loadTrails();
    const hikes = loadHikes();
    const hikedNames = new Set(hikes.map(h => h.trail_name));
    const hikedIDs = new Set(hikes.filter(h => h.trail_id).map(h => h.trail_id));
    const cfg = loadConfig();
    const home = { lat: cfg.homeLat, lon: cfg.homeLon };

    if (difficulty) trails = trails.filter(t => t.difficulty === difficulty);
    if (dog_friendly) trails = trails.filter(t => t.dogFriendly === true);
    if (max_distance_miles) trails = trails.filter(t => !t.distanceMiles || t.distanceMiles <= max_distance_miles);
    if (min_distance_miles) trails = trails.filter(t => !t.distanceMiles || t.distanceMiles >= min_distance_miles);

    trails = trails.map(t => {
      const isHiked = hikedNames.has(t.name) || hikedIDs.has(t.id);
      const driveDist = haversineDistanceMiles(home.lat, home.lon, t.trailheadLat, t.trailheadLon);
      const trailHikes = hikes.filter(h => h.trail_name === t.name || h.trail_id === t.id);
      return { ...t, isHiked, driveDist: Math.round(driveDist * 10) / 10, hikeCount: trailHikes.length };
    });

    if (max_drive_miles) trails = trails.filter(t => t.driveDist <= max_drive_miles);
    if (!include_wishlist) trails = trails.filter(t => t.isHiked);
    if (!include_hiked) trails = trails.filter(t => !t.isHiked);

    if (for_person === "shaun") trails = trails.filter(t => t.lovedByShaun || !t.isHiked);
    if (for_person === "julie") trails = trails.filter(t => t.lovedByJulie || !t.isHiked);
    if (for_person === "both") trails = trails.filter(t => (t.lovedByShaun && t.lovedByJulie) || !t.isHiked);

    // Score: loved > wishlist > not-recently-hiked
    trails.sort((a, b) => {
      const aLoved = (a.lovedByShaun ? 1 : 0) + (a.lovedByJulie ? 1 : 0);
      const bLoved = (b.lovedByShaun ? 1 : 0) + (b.lovedByJulie ? 1 : 0);
      if (aLoved !== bLoved) return bLoved - aLoved;
      if (a.isHiked !== b.isHiked) return a.isHiked ? 1 : -1;
      return a.driveDist - b.driveDist;
    });

    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          count: trails.length,
          recommendations: trails.slice(0, 20).map(t => ({
            name: t.name,
            region: t.region,
            url: t.url || null,
            distance_miles: t.distanceMiles || null,
            elevation_gain_ft: t.elevationGainFt || null,
            difficulty: t.difficulty || null,
            dog_friendly: t.dogFriendly || null,
            loved_by_shaun: t.lovedByShaun || false,
            loved_by_julie: t.lovedByJulie || false,
            is_wishlist: !t.isHiked,
            drive_distance_miles: t.driveDist,
            times_hiked: t.hikeCount,
            coordinates: { lat: t.trailheadLat, lon: t.trailheadLon },
          })),
        }, null, 2),
      }],
    };
  }
);

server.tool(
  "get_all_regions",
  "List all regions with trail and hike counts",
  {},
  async () => {
    const trails = loadTrails();
    const hikes = loadHikes();
    const regions = {};
    trails.forEach(t => {
      if (!regions[t.region]) regions[t.region] = { trails: 0, hikes: 0 };
      regions[t.region].trails++;
    });
    hikes.forEach(h => {
      if (!regions[h.region]) regions[h.region] = { trails: 0, hikes: 0 };
      regions[h.region].hikes++;
    });
    return {
      content: [{
        type: "text",
        text: JSON.stringify(
          Object.entries(regions)
            .map(([name, data]) => ({ name, ...data }))
            .sort((a, b) => b.hikes - a.hikes),
          null, 2
        ),
      }],
    };
  }
);

server.tool(
  "get_all_hikes",
  "Get every individual hike record with optional filters — ideal for time-based analysis",
  {
    year: z.string().optional().describe("Filter by year (e.g. '2024')"),
    month: z.string().optional().describe("Filter by month (e.g. '10' for October)"),
    region: z.string().optional().describe("Filter by region"),
    date_from: z.string().optional().describe("Start date inclusive (YYYY-MM-DD)"),
    date_to: z.string().optional().describe("End date inclusive (YYYY-MM-DD)"),
    trail_name: z.string().optional().describe("Filter by trail name (partial match)"),
  },
  async ({ year, month, region, date_from, date_to, trail_name }) => {
    let hikes = loadHikes();
    if (year) hikes = hikes.filter(h => h.date.startsWith(year));
    if (month) { const m = month.padStart(2, "0"); hikes = hikes.filter(h => h.date.slice(5, 7) === m); }
    if (region) hikes = hikes.filter(h => h.region === region);
    if (date_from) hikes = hikes.filter(h => h.date >= date_from);
    if (date_to) hikes = hikes.filter(h => h.date <= date_to);
    if (trail_name) { const q = trail_name.toLowerCase(); hikes = hikes.filter(h => h.trail_name.toLowerCase().includes(q)); }

    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          count: hikes.length,
          hikes: hikes.map(h => ({
            date: h.date,
            trail_name: h.trail_name,
            region: h.region,
            distance_miles: h.distance_miles,
            elevation_gain_ft: h.elevation_gain_ft,
            duration_minutes: h.duration_minutes,
          })),
        }, null, 2),
      }],
    };
  }
);

server.tool(
  "get_monthly_stats",
  "Get aggregated hiking stats broken down by month — great for leaderboards and comparisons",
  {
    year: z.string().optional().describe("Filter to a specific year (e.g. '2022'). Omit for all-time monthly breakdown."),
  },
  async ({ year }) => {
    let hikes = loadHikes();
    if (year) hikes = hikes.filter(h => h.date.startsWith(year));

    const months = {};
    hikes.forEach(h => {
      const key = h.date.slice(0, 7); // YYYY-MM
      if (!months[key]) months[key] = { hikes: 0, miles: 0, elevation_ft: 0, duration_minutes: 0, trails: new Set(), regions: new Set() };
      const m = months[key];
      m.hikes++;
      m.miles += h.distance_miles;
      m.elevation_ft += h.elevation_gain_ft;
      m.duration_minutes += h.duration_minutes;
      m.trails.add(h.trail_name);
      m.regions.add(h.region);
    });

    const result = Object.entries(months)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([month, m]) => ({
        month,
        hikes: m.hikes,
        miles: Math.round(m.miles * 10) / 10,
        elevation_ft: Math.round(m.elevation_ft),
        duration_hours: Math.round(m.duration_minutes / 60 * 10) / 10,
        unique_trails: m.trails.size,
        unique_regions: m.regions.size,
      }));

    return {
      content: [{
        type: "text",
        text: JSON.stringify({ count: result.length, months: result }, null, 2),
      }],
    };
  }
);

server.tool(
  "get_streaks",
  "Track hiking streaks — consecutive Saturdays hiked, longest gaps, current streak",
  {},
  async () => {
    const hikes = loadHikes();
    if (!hikes.length) return { content: [{ type: "text", text: JSON.stringify({ error: "No hikes found" }) }] };

    // Get unique hike dates sorted ascending
    const dates = [...new Set(hikes.map(h => h.date))].sort();

    // Saturday streaks
    const allSaturdays = [];
    const first = new Date(dates[0] + "T12:00:00");
    const last = new Date(dates[dates.length - 1] + "T12:00:00");
    // Find first Saturday on or before first hike
    const start = new Date(first);
    start.setDate(start.getDate() - start.getDay() + 6); // next Saturday
    if (start > first) start.setDate(start.getDate() - 7);

    const hikeDateSet = new Set(dates);
    for (let d = new Date(start); d <= last; d.setDate(d.getDate() + 7)) {
      const ds = d.toISOString().slice(0, 10);
      allSaturdays.push({ date: ds, hiked: hikeDateSet.has(ds) });
    }

    // Also check the Saturday after the last hike up to today
    const today = new Date();
    const lastSat = new Date(allSaturdays[allSaturdays.length - 1]?.date + "T12:00:00");
    for (let d = new Date(lastSat); d.setDate(d.getDate() + 7), d <= today;) {
      const ds = d.toISOString().slice(0, 10);
      allSaturdays.push({ date: ds, hiked: hikeDateSet.has(ds) });
    }

    // Compute Saturday streaks
    let currentStreak = 0, longestStreak = 0, longestStreakStart = "", longestStreakEnd = "";
    let streakStart = "";
    let tempStreak = 0;
    for (const sat of allSaturdays) {
      if (sat.hiked) {
        tempStreak++;
        if (tempStreak === 1) streakStart = sat.date;
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
          longestStreakStart = streakStart;
          longestStreakEnd = sat.date;
        }
      } else {
        tempStreak = 0;
      }
    }
    // Current streak: count backwards from most recent Saturday
    currentStreak = 0;
    let currentStreakStart = "";
    for (let i = allSaturdays.length - 1; i >= 0; i--) {
      if (allSaturdays[i].hiked) {
        currentStreak++;
        currentStreakStart = allSaturdays[i].date;
      } else {
        break;
      }
    }

    // Longest gap between any consecutive hikes
    let longestGapDays = 0, longestGapFrom = "", longestGapTo = "";
    for (let i = 1; i < dates.length; i++) {
      const gap = (new Date(dates[i] + "T12:00:00") - new Date(dates[i - 1] + "T12:00:00")) / 86400000;
      if (gap > longestGapDays) {
        longestGapDays = gap;
        longestGapFrom = dates[i - 1];
        longestGapTo = dates[i];
      }
    }

    // Weekly streaks (any day in the week counts)
    const hikeWeeks = new Set(dates.map(d => {
      const dt = new Date(d + "T12:00:00");
      const jan1 = new Date(dt.getFullYear(), 0, 1);
      const week = Math.ceil(((dt - jan1) / 86400000 + jan1.getDay() + 1) / 7);
      return `${dt.getFullYear()}-W${String(week).padStart(2, "0")}`;
    }));
    const sortedWeeks = [...hikeWeeks].sort();
    let weekStreak = 0, longestWeekStreak = 0;
    // Simple consecutive week check by ISO week parsing
    for (let i = 0; i < sortedWeeks.length; i++) {
      if (i === 0) { weekStreak = 1; }
      else {
        const [py, pw] = sortedWeeks[i - 1].split("-W").map(Number);
        const [cy, cw] = sortedWeeks[i].split("-W").map(Number);
        const isConsecutive = (cy === py && cw === pw + 1) || (cy === py + 1 && pw >= 51 && cw === 1);
        weekStreak = isConsecutive ? weekStreak + 1 : 1;
      }
      if (weekStreak > longestWeekStreak) longestWeekStreak = weekStreak;
    }

    // Saturday hike rate
    const totalSaturdays = allSaturdays.length;
    const saturdaysHiked = allSaturdays.filter(s => s.hiked).length;

    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          saturday_streaks: {
            current_streak: currentStreak,
            current_streak_start: currentStreakStart || null,
            longest_streak: longestStreak,
            longest_streak_period: { from: longestStreakStart, to: longestStreakEnd },
            saturdays_hiked: saturdaysHiked,
            total_saturdays: totalSaturdays,
            saturday_hike_rate: Math.round(saturdaysHiked / totalSaturdays * 1000) / 10 + "%",
          },
          weekly_streaks: {
            longest_consecutive_weeks: longestWeekStreak,
          },
          gaps: {
            longest_gap_days: longestGapDays,
            longest_gap_period: { from: longestGapFrom, to: longestGapTo },
          },
          total_unique_hike_days: dates.length,
          date_range: { first: dates[0], last: dates[dates.length - 1] },
        }, null, 2),
      }],
    };
  }
);

// Start
const transport = new StdioServerTransport();
await server.connect(transport);
