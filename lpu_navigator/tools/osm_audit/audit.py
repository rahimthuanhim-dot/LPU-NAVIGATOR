"""Audit OSM coverage for offline pedestrian routing at LPU."""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
RAW = ROOT / "raw"
OUT = ROOT / "out"
UA = "lpu-navigator-audit/0.1"
DEFAULT_ENDPOINT = "https://overpass-api.de/api/interpreter"
BBOX = (31.235, 31.272, 75.680, 75.725)
HIGHWAYS = "footway|path|pedestrian|steps|living_street|service|residential|track|cycleway|unclassified|tertiary"
POI_AMENITIES = "library|cafe|restaurant|food_court|fast_food|canteen|bank|atm|hospital|clinic|post_office"
BLOCK_RE = re.compile(r"\b(block|blk)[\s\-.]*\d+", re.I)
last_call = 0.0
query_log: list[dict[str, Any]] = []


def now_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ%f")


def overpass(endpoint: str, query: str, timeout: int, label: str) -> dict[str, Any]:
    global last_call
    wait = 1.0 - (time.monotonic() - last_call)
    if wait > 0:
        time.sleep(wait)
    stamp = f"{now_stamp()}_{label}"
    RAW.mkdir(parents=True, exist_ok=True)
    (RAW / f"{stamp}_query.ql").write_text(query, encoding="utf-8")
    request = urllib.request.Request(
        endpoint,
        data=urllib.parse.urlencode({"data": query}).encode(),
        headers={"User-Agent": UA, "Content-Type": "application/x-www-form-urlencoded"},
    )
    errors: list[str] = []
    for attempt in range(4):
        last_call = time.monotonic()
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                body = response.read()
            payload = json.loads(body)
            (RAW / f"{stamp}_response.json").write_bytes(body)
            query_log.append({
                "label": label,
                "query": query,
                "outcome": "success",
                "count": len(elements(payload)),
            })
            return payload
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            errors.append(f"attempt {attempt + 1}: {getattr(exc, 'reason', str(exc))}")
            if attempt < 3:
                time.sleep(2**attempt)
    error = "Overpass failed after 4 attempts: " + " | ".join(errors)
    query_log.append({"label": label, "query": query, "outcome": "failed", "error": error})
    raise RuntimeError(error)


def bbox_filter() -> str:
    south, north, west, east = BBOX
    return f"{south},{west},{north},{east}"


def poly_filter(points: list[tuple[float, float]]) -> str:
    if len(points) < 3:
        return bbox_filter()
    return 'poly:"' + " ".join(f"{lat} {lon}" for lat, lon in points) + '"'


def elements(payload: dict[str, Any]) -> list[dict[str, Any]]:
    return payload.get("elements", [])


def tags(element: dict[str, Any]) -> dict[str, str]:
    return element.get("tags", {})


def coords(element: dict[str, Any]) -> tuple[float, float] | None:
    if "lat" in element:
        return element["lat"], element["lon"]
    center = element.get("center")
    if center:
        return center["lat"], center["lon"]
    geometry = element.get("geometry", [])
    return (geometry[0]["lat"], geometry[0]["lon"]) if geometry else None


def project(point: tuple[float, float], origin: tuple[float, float]) -> tuple[float, float]:
    scale = 111320.0
    return (
        (point[1] - origin[1]) * scale * math.cos(math.radians(origin[0])),
        (point[0] - origin[0]) * scale,
    )


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    lat0 = math.radians((a[0] + b[0]) / 2)
    return math.hypot((b[0] - a[0]) * 111320, (b[1] - a[1]) * 111320 * math.cos(lat0))


def way_points(way: dict[str, Any], node_map: dict[int, tuple[float, float]]) -> list[tuple[float, float]]:
    if way.get("geometry"):
        return [(n["lat"], n["lon"]) for n in way["geometry"]]
    return [node_map[n] for n in way.get("nodes", []) if n in node_map]


def point_segment_distance(
    p: tuple[float, float], a: tuple[float, float], b: tuple[float, float], origin: tuple[float, float]
) -> float:
    px, py = project(p, origin)
    ax, ay = project(a, origin)
    bx, by = project(b, origin)
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy or 1)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def point_in_polygon(p: tuple[float, float], polygon: list[tuple[float, float]]) -> bool:
    inside = False
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if (a[1] > p[1]) != (b[1] > p[1]):
            x = (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]
            if p[0] < x:
                inside = not inside
    return inside


def point_on_polygon_boundary(p: tuple[float, float], polygon: list[tuple[float, float]]) -> bool:
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if segments_touch(p, p, a, b):
            return True
    return False


def point_strictly_in_polygon(p: tuple[float, float], polygon: list[tuple[float, float]]) -> bool:
    return point_in_polygon(p, polygon) and not point_on_polygon_boundary(p, polygon)


def orient(a: tuple[float, float], b: tuple[float, float], c: tuple[float, float]) -> float:
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def segments_touch(a: tuple[float, float], b: tuple[float, float],
                   c: tuple[float, float], d: tuple[float, float]) -> bool:
    return (
        max(min(a[0], b[0]), min(c[0], d[0])) <= min(max(a[0], b[0]), max(c[0], d[0]))
        and max(min(a[1], b[1]), min(c[1], d[1])) <= min(max(a[1], b[1]), max(c[1], d[1]))
        and orient(a, b, c) * orient(a, b, d) <= 0
        and orient(c, d, a) * orient(c, d, b) <= 0
    )


def proper_crossing(a: tuple[float, float], b: tuple[float, float],
                    c: tuple[float, float], d: tuple[float, float]) -> bool:
    return orient(a, b, c) * orient(a, b, d) < 0 and orient(c, d, a) * orient(c, d, b) < 0


def classify_edge_against_polygon(
    segment: list[tuple[float, float]], polygon: list[tuple[float, float]]
) -> str | None:
    """Classify an edge against a polygon, excluding endpoint-only crossings."""
    midpoint = (
        (segment[0][0] + segment[1][0]) / 2,
        (segment[0][1] + segment[1][1]) / 2,
    )
    touching = False
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if proper_crossing(segment[0], segment[1], a, b):
            return "crossing"
        if segments_touch(segment[0], segment[1], a, b):
            touching = True
    if point_strictly_in_polygon(midpoint, polygon):
        return "crossing"
    return "touching" if touching else None


def polygon_area_m2(polygon: list[tuple[float, float]]) -> float:
    if len(polygon) < 3:
        return 0.0
    origin = polygon[0]
    points = [project(p, origin) for p in polygon]
    return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(points, points[1:] + points[:1]))) / 2


def polygon_bbox(polygon: list[tuple[float, float]]) -> tuple[float, float, float, float] | None:
    if not polygon:
        return None
    lats, lons = zip(*polygon)
    return min(lats), min(lons), max(lats), max(lons)


def components(adjacency: dict[int, set[int]]) -> list[set[int]]:
    seen: set[int] = set()
    result: list[set[int]] = []
    for start in adjacency:
        if start in seen:
            continue
        group: set[int] = set()
        stack = [start]
        seen.add(start)
        while stack:
            node = stack.pop()
            group.add(node)
            for other in adjacency[node]:
                if other not in seen:
                    seen.add(other)
                    stack.append(other)
        result.append(group)
    return sorted(result, key=len, reverse=True)


def geojson_feature(geometry: dict[str, Any], kind: str, osm_tags: dict[str, str]) -> dict[str, Any]:
    return {
        "type": "Feature",
        "geometry": geometry,
        "properties": {"source": "OpenStreetMap", "verified": False, "kind": kind, "osm_tags": osm_tags},
    }


def query_texts(area: str) -> dict[str, str]:
    return {
        "buildings": (
            f'[out:json][timeout:180];(way["building"]({area});relation["building"]({area}););'
            "out body geom;>;out skel qt;"
        ),
        "walkable": (
            f'[out:json][timeout:180];way["highway"~"^({HIGHWAYS})$"]({area});'
            "out body geom;>;out skel qt;"
        ),
        "entrances": (
            f'[out:json][timeout:180];(node["entrance"]({area});node["door"]({area});'
            f'node["barrier"="gate"]({area}););out tags geom;'
        ),
        "pois": (
            f'[out:json][timeout:180];(nwr["amenity"~"^({POI_AMENITIES})$"]({area});'
            f'nwr["building"~"^(dormitory|hostel|university)$"]({area});'
            f'nwr["leisure"~"^(sports_centre|pitch|stadium)$"]({area});'
            f'nwr["tourism"]({area});nwr["shop"]({area});nwr["name"]({area});'
            f'nwr["ref"]({area}););out body center geom;'
        ),
    }


def write_failure_report(error: str) -> None:
    report = [
        "# LPU OSM pedestrian-routing audit",
        f"Generated: {datetime.now(timezone.utc).isoformat()}",
        "Audit stopped before analysis because the public Overpass API failed.",
        "",
        "## Exact error",
        f"- {error}",
        "",
        "## Overpass queries",
    ]
    for item in query_log:
        count = f"; element count: {item['count']}" if item["outcome"] == "success" else ""
        report += [
            f"### {item['label']} — {item['outcome']}{count}",
            "```overpass",
            item["query"],
            "```",
            f"- Error: {item['error']}" if item["outcome"] == "failed" else "",
        ]
    report += [
        "",
        "No derived counts or verification claims were produced.",
        "",
        "© OpenStreetMap contributors (ODbL)",
        "",
    ]
    (ROOT / "REPORT.md").write_text("\n".join(report), encoding="utf-8")


def destination_key(element: dict[str, Any]) -> tuple[str, int]:
    return element["type"], int(element["id"])


def feature_point(element: dict[str, Any], origin: tuple[float, float]) -> tuple[float, float] | None:
    point = coords(element)
    if point:
        return point
    geometry = element.get("geometry", [])
    if not geometry:
        return None
    points = [(n["lat"], n["lon"]) for n in geometry]
    x = sum(project(p, origin)[0] for p in points) / len(points)
    y = sum(project(p, origin)[1] for p in points) / len(points)
    return origin[0] + y / 111320, origin[1] + x / (111320 * math.cos(math.radians(origin[0])))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", default=DEFAULT_ENDPOINT)
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    query_payloads: dict[str, dict[str, Any]] = {}
    query_text_by_label: dict[str, str] = {}
    try:
        boundary_queries = {
            "boundary_a": '[out:json][timeout:60];way(422435593);out tags geom;',
            "boundary_b": '[out:json][timeout:60];relation(21599790);out tags geom;',
            "name_search": (
                '[out:json][timeout:60];(nwr["amenity"~"^(university|college)$"]["name"~"LPU",i]'
                '(around:3000,31.2534,75.7035);nwr["landuse"="education"]["name"~"LPU",i]'
                '(around:3000,31.2534,75.7035););out tags center geom;'
            ),
        }
        for label, query in boundary_queries.items():
            query_text_by_label[label] = query
            query_payloads[label] = overpass(args.endpoint, query, args.timeout, label)
        a = elements(query_payloads["boundary_a"])
        b = elements(query_payloads["boundary_b"])
        a_geometry = a[0].get("geometry", []) if a else []
        a_tags = tags(a[0]) if a else {}
        b_tags = tags(b[0]) if b else {}
        if not b:
            candidate_b_reason = "not found"
        elif b[0].get("type") != "relation":
            candidate_b_reason = f"element type is {b[0].get('type')!r}, not relation"
        elif b_tags.get("name") != "Lovely Professional University":
            candidate_b_reason = f"exact name mismatch (found {b_tags.get('name', '<unnamed>')!r})"
        elif b_tags.get("type") not in {"multipolygon", "boundary"}:
            candidate_b_reason = f"relation type is not multipolygon/boundary (tags type={b_tags.get('type')!r})"
        else:
            candidate_b_reason = ""
        if not a:
            rejection = "not found"
        elif a_tags.get("name") != "Lovely Professional University":
            rejection = f"name mismatch (found {a_tags.get('name', '<unnamed>')!r})"
        elif len(a_geometry) < 4 or a_geometry[0] != a_geometry[-1]:
            rejection = "not closed"
        else:
            rejection = ""
        use_a = not rejection
        boundary_points = [(n["lat"], n["lon"]) for n in a_geometry] if use_a else []
        area = poly_filter(boundary_points) if use_a else bbox_filter()
        boundary_reason = (
            "Candidate A is a closed way named Lovely Professional University."
            if use_a else f"Candidate A rejected: {rejection}; using the fallback bbox."
        )
        query_texts_for_area = query_texts(area)
        for label, query in query_texts_for_area.items():
            query_text_by_label[label] = query
            query_payloads[label] = overpass(args.endpoint, query, args.timeout, label)
    except RuntimeError as exc:
        write_failure_report(str(exc))
        print(str(exc), file=sys.stderr)
        return 1

    building_elements = elements(query_payloads["buildings"])
    buildings = [e for e in building_elements if e.get("type") == "way"]
    building_relations = [e for e in building_elements if e.get("type") == "relation"]
    walkable_elements = elements(query_payloads["walkable"])
    walkable = [e for e in walkable_elements if e.get("type") == "way"]
    entrances = elements(query_payloads["entrances"])
    poi_elements = elements(query_payloads["pois"])
    origin_candidates = [coords(e) for e in walkable]
    origin_candidates = [p for p in origin_candidates if p]
    origin = (
        sum(p[0] for p in origin_candidates) / max(1, len(origin_candidates)),
        sum(p[1] for p in origin_candidates) / max(1, len(origin_candidates)),
    )
    node_map = {
        int(e["id"]): (e["lat"], e["lon"])
        for e in walkable_elements if e.get("type") == "node" and "lat" in e and "lon" in e
    }
    adjacency: dict[int, set[int]] = defaultdict(set)
    edge_records: list[tuple[int, int, float, str, dict[str, str], list[tuple[float, float]]]] = []
    excluded = 0
    highway_counts: Counter[str] = Counter()
    highway_lengths: Counter[str] = Counter()
    seen_edges: Counter[tuple[int, int]] = Counter()
    for way in walkable:
        t = tags(way)
        if t.get("foot") == "no" or t.get("access") in {"no", "private"}:
            excluded += 1
            continue
        points = way_points(way, node_map)
        refs = [int(n["id"]) for n in way.get("geometry", []) if "id" in n] or [int(n) for n in way.get("nodes", [])]
        for first, second, pa, pb in zip(refs, refs[1:], points, points[1:]):
            length = distance(pa, pb)
            seen_edges[tuple(sorted((first, second)))] += 1
            adjacency[first].add(second)
            adjacency[second].add(first)
            edge_records.append((first, second, length, t.get("highway", "unknown"), dict(t), [pa, pb]))
            highway_counts[t.get("highway", "unknown")] += 1
            highway_lengths[t.get("highway", "unknown")] += length
    comps = components(adjacency)
    largest = comps[0] if comps else set()
    raw_edges = len(edge_records)
    unique_edges = len(seen_edges)
    duplicate_edges = raw_edges - unique_edges
    cycle_count = unique_edges - len(adjacency) + len(comps)

    building_names = sorted({tags(b)["name"] for b in buildings if tags(b).get("name")})
    building_refs = sorted({tags(b)["ref"] for b in buildings if tags(b).get("ref")})
    digit_review = sorted({
        value for b in buildings for value in (tags(b).get("name"), tags(b).get("ref"))
        if value and re.search(r"\d", value)
    })
    building_stats = {
        "total": len(buildings),
        "named": sum(bool(tags(b).get("name")) for b in buildings),
        "ref": sum(bool(tags(b).get("ref")) for b in buildings),
        "block_number": sum(bool(BLOCK_RE.search(" ".join(tags(b).get(k, "") for k in ("name", "ref", "alt_name")))) for b in buildings),
        "addr": sum(any(k.startswith("addr:") for k in tags(b)) for b in buildings),
    }
    node_map_all = dict(node_map)
    polygons = [(b, way_points(b, node_map_all)) for b in buildings if len(way_points(b, node_map_all)) >= 3]
    entrance_on_outline = sum(
        bool(coords(e)) and any(
            min(point_segment_distance(coords(e), a, b, origin) for a, b in zip(poly, poly[1:] + poly[:1])) <= 5
            for _, poly in polygons
        ) for e in entrances
    )
    proper_crossings = 0
    touching_edges = 0
    crossing_worst: list[tuple[float, str]] = []
    for first, second, length, highway, _, segment in edge_records:
        classifications = [classify_edge_against_polygon(segment, poly) for _, poly in polygons]
        if "crossing" in classifications:
            proper_crossings += 1
            crossing_worst.append((length, f"{first}-{second} ({highway}, {length:.2f} m)"))
        elif "touching" in classifications:
            touching_edges += 1
    crossing_worst.sort(reverse=True)

    named_buildings = [b for b in buildings if tags(b).get("name")]
    poi_candidates = [
        e for e in poi_elements
        if tags(e).get("name") and any(k in tags(e) for k in ("amenity", "leisure", "tourism", "shop", "building"))
        and not any(k in tags(e) for k in ("highway", "landuse", "boundary", "natural", "waterway", "place"))
    ]
    destinations_before = len(named_buildings) + len(poi_candidates)
    destination_map = {destination_key(e): e for e in named_buildings + poi_candidates}
    destinations = list(destination_map.values())
    destination_distances: list[tuple[tuple[str, int], str, tuple[float, float], float, bool]] = []
    for e in destinations:
        if e.get("type") == "relation":
            continue
        p = feature_point(e, origin)
        if not p or not adjacency:
            continue
        if e.get("type") == "way":
            polygon = way_points(e, node_map_all)
            nearest_distance = min(
                min(point_segment_distance(node_map[n], a, b, origin) for a, b in zip(polygon, polygon[1:] + polygon[:1]))
                for n in adjacency
            ) if len(polygon) >= 2 else float("inf")
        else:
            nearest_distance = min(distance(p, node_map[n]) for n in adjacency)
        if e.get("type") == "way" and len(polygon) >= 2:
            nearest = min(
                adjacency,
                key=lambda n: min(
                    point_segment_distance(node_map[n], a, b, origin)
                    for a, b in zip(polygon, polygon[1:] + polygon[:1])
                ),
            )
        else:
            nearest = min(adjacency, key=lambda n: distance(p, node_map[n]))
        destination_distances.append((destination_key(e), tags(e).get("name", "<unnamed>"), p, nearest_distance, nearest in largest))
    within_30 = sum(d <= 30 for _, _, _, d, _ in destination_distances)
    within_60 = sum(d <= 60 for _, _, _, d, _ in destination_distances)
    over_60 = sum(d > 60 for _, _, _, d, _ in destination_distances)

    grid: defaultdict[tuple[int, int], dict[str, Any]] = defaultdict(lambda: {"nodes": set(), "names": []})
    for n in largest:
        x, y = project(node_map[n], origin)
        grid[(math.floor(x / 300), math.floor(y / 300))]["nodes"].add(n)
    destination_by_key = {key: (name, point) for key, name, point, _, _ in destination_distances}
    for key, _, _, _, in_largest in destination_distances:
        if in_largest:
            name, point = destination_by_key[key]
            x, y = project(point, origin)
            grid[(math.floor(x / 300), math.floor(y / 300))]["names"].append(name)
    zones = []
    for cell, value in grid.items():
        nodes = value["nodes"]
        zone_edges = {tuple(sorted((a, b))) for a, b, *_ in edge_records if a in nodes and b in nodes}
        subcomponents = components({n: {x for x in adjacency[n] if x in nodes} for n in nodes})
        zones.append((len(value["names"]), len(zone_edges) - len(nodes) + len(subcomponents),
                      origin[0] + (cell[1] + 0.5) * 300 / 111320,
                      origin[1] + (cell[0] + 0.5) * 300 / (111320 * math.cos(math.radians(origin[0]))),
                      sorted(value["names"])))
    zones.sort(reverse=True)

    OUT.mkdir(parents=True, exist_ok=True)
    features = []
    for b in buildings:
        poly = way_points(b, node_map_all)
        if len(poly) >= 3:
            features.append(geojson_feature({"type": "Polygon", "coordinates": [[[p[1], p[0]] for p in poly]]}, "building", tags(b)))
    for first, second, _, _, osm_tags, segment in edge_records:
        features.append(geojson_feature(
            {"type": "LineString", "coordinates": [[p[1], p[0]] for p in segment]},
            "graph_edge",
            osm_tags,
        ))
    for e in entrances:
        p = coords(e)
        if p:
            features.append(geojson_feature({"type": "Point", "coordinates": [p[1], p[0]]}, "entrance", tags(e)))
    (OUT / "audit.geojson").write_text(json.dumps({"type": "FeatureCollection", "features": features}, indent=2), encoding="utf-8")

    largest_pct = 100 * len(largest) / len(adjacency) if adjacency else 0
    candidate_a_bbox = polygon_bbox([(n["lat"], n["lon"]) for n in a_geometry])
    passfail = [
        ("Largest component >= 90% of walkable nodes", largest_pct >= 90, f"{largest_pct:.6f}%"),
        ("Named buildings >= 50% of buildings", building_stats["named"] >= building_stats["total"] * 0.5, str(building_stats["named"])),
        ("At least 10 buildings with a block number", building_stats["block_number"] >= 10, str(building_stats["block_number"])),
        ("Entrance nodes present", bool(entrances), str(len(entrances))),
        ("At least 20 graph cycles", cycle_count >= 20, str(cycle_count)),
        ("Old shorter-than-straight-line criterion", None, "not meaningful for single-segment edges"),
    ]
    report = [
        "# LPU OSM pedestrian-routing audit",
        f"Generated: {datetime.now(timezone.utc).isoformat()}",
        "All OSM data and derived rows are **unverified**.",
        "",
        "## Boundary decision",
        f"- {boundary_reason}",
        f"- Candidate A tags: {json.dumps(a_tags)}",
        f"- Candidate A closed-way area: {polygon_area_m2([(n['lat'], n['lon']) for n in a_geometry]) / 1_000_000:.6f} km²",
        f"- Candidate A bounding box (south, west, north, east): {candidate_a_bbox}",
        f"- Candidate B tags: {json.dumps(b_tags)}; validation: {'accepted' if not candidate_b_reason else 'rejected'}"
        f"; reason: {candidate_b_reason or 'exact campus name plus multipolygon/boundary relation type'}",
        f"- Name search element count: {len(elements(query_payloads['name_search']))}",
        f"- Analysis area: `{area}`",
        "",
        "## Overpass queries and element counts",
    ]
    for item in query_log:
        count = f"; element count: {item['count']}" if item["outcome"] == "success" else ""
        report += [
            f"### {item['label']} — {item['outcome']}{count}",
            "```overpass",
            item["query"],
            "```",
            f"- Error: {item['error']}" if item["outcome"] == "failed" else "",
        ]
    report += [
        "## Graph",
        f"- Walkable ways fetched: {len(walkable)}; excluded ways: {excluded}",
        f"- Nodes: {len(adjacency)}; raw edges: {raw_edges}; unique edges: {unique_edges}; duplicate edges: {duplicate_edges}; components: {len(comps)}",
        f"- Ten largest component sizes: {[len(c) for c in comps[:10]]}",
        f"- Largest component: {len(largest)} nodes ({largest_pct:.6f}%); cycle count using unique edges: {cycle_count}",
        "",
        "## Highway breakdown",
    ]
    report += [f"- {k}: {highway_counts[k]} edges, {highway_lengths[k]:.6f} m" for k in sorted(highway_counts)]
    report += [
        "",
        "## Buildings",
        f"- Building ways: {len(buildings)}; building relations/multipolygons: {len(building_relations)}; relations skipped from geometry analysis: {len(building_relations)}",
        "- Skipped building relations are also excluded from destination connectivity analysis.",
        f"- Total ways: {building_stats['total']}; named: {building_stats['named']}; with ref: {building_stats['ref']}; block/blk number: {building_stats['block_number']}; with addr tags: {building_stats['addr']}",
        f"- Names: {building_names}",
        f"- Refs: {building_refs}",
        f"- Names/refs containing a digit for manual review: {digit_review}",
        "",
        "## Entrances and destinations",
        f"- Entrance/door/gate nodes: {len(entrances)}; on a building outline (5 m tolerance): {entrance_on_outline}",
        f"- Destination candidates before de-duplication: {destinations_before}; after de-duplication: {len(destinations)}; analyzed: {len(destination_distances)}",
        f"- Within 30 m: {within_30}; within 60 m: {within_60}; over 60 m: {over_60}",
        "",
        "## Defects",
        f"- Dead-end nodes (degree 1): {sum(len(v) == 1 for v in adjacency.values())}",
        f"- Edges that properly cross a building outline or have midpoint strictly inside: {proper_crossings}; ten worst: {[x[1] for x in crossing_worst[:10]]}",
        f"- Edges that merely touch an outline: {touching_edges}",
        f"- Duplicate edges: {duplicate_edges}; zero-length edges: {sum(length == 0 for _, _, length, _, _, _ in edge_records)}",
        "",
        "## Sanity list: 10 longest edges",
    ]
    for first, second, length, highway, _, _ in sorted(edge_records, key=lambda item: item[2], reverse=True)[:10]:
        report.append(f"- {length:.6f} m; {highway}; nodes {first}, {second}")
    report += ["", "## Pilot-zone shortlist (heuristic)"]
    for i, (count, cycles, lat, lon, names) in enumerate(zones[:3], 1):
        report.append(f"{i}. Centre {lat:.8f}, {lon:.8f}; named destinations: {count}; graph cycles: {cycles}; names: {names}")
    report += ["", "## Pass/fail", "| Criterion | Result | Number |", "|---|---|---|"]
    for label, result, value in passfail:
        report.append(f"| {label} | {'not meaningful' if result is None else ('pass' if result else 'fail')} | {value} |")
    report += ["", "© OpenStreetMap contributors (ODbL)", ""]
    (ROOT / "REPORT.md").write_text("\n".join(report), encoding="utf-8")
    print(boundary_reason)
    for label in query_text_by_label:
        print(f"{label}: {len(elements(query_payloads[label]))} elements")
    print(f"Wrote {ROOT / 'REPORT.md'} and {OUT / 'audit.geojson'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
