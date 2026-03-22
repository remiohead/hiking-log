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
    region: z.string().optional().describe("Filter by region"),
  },
  async ({ year, region }) => {
    let hikes = loadHikes();
    if (year) hikes = hikes.filter(h => h.date.startsWith(year));
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

// Start
const transport = new StdioServerTransport();
await server.connect(transport);
