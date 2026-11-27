class_name MatchConfig
extends RefCounted
## Hands the menu's choices to the game scene (P1-32), and builds skirmish
## scenarios from them. A static variable instead of an autoload, per the
## "no autoloads" coding standard.

## Scenario dictionary for the next match (see MatchSetup), or empty.
static var pending: Dictionary = {}
## A save (SaveGame.read) to load instead of a new match (P3-22), or empty.
static var load_save: Dictionary = {}
## Faction ids that are playable in skirmish, with display names.
## Playable now. The UAE (`ae`) and the EU (`eu`) join when their rosters
## are built (docs/design/factions.md).
const FACTIONS: Dictionary = {"us": "America", "kp": "North Korea"}


## A 1v1 skirmish: player 1 (human, or AI when watching) against an AI.
static func skirmish(content: ContentDb, map_id: String, faction: String, credits: int, watch_only: bool = false,
		difficulty: String = "normal") -> Dictionary:
	var map: MapDef = content.get_map(map_id)
	var enemy: String = "kp" if faction == "us" else "us"
	var players: Array = [
		{"id": 1, "team": 1, "faction": faction, "credits": credits},
		{"id": 2, "team": 2, "faction": enemy, "credits": credits, "ai": enemy + "_default", "difficulty": difficulty},
	]
	if watch_only:
		players[0]["ai"] = faction + "_default"
		players[0]["difficulty"] = "normal"
	var spawns: Array = []
	for slot: int in 2:
		var f: String = players[slot]["faction"]
		var start: Vector2i = map.start_positions[slot] if slot < map.start_positions.size() else Vector2i(20 + slot * 80, 50)
		var mirror: int = -1 if start.x > map.width_m / 2 else 1
		for item: Variant in content.start_kit:
			var kit: Array = item
			spawns.append({
				"def": str(kit[0]).replace("{f}", f), "player": slot + 1,
				"x_m": start.x + int(kit[1]) * mirror, "y_m": start.y + int(kit[2]),
				"facing_deg": 0 if mirror > 0 else 180,
			})
	return {
		"id": "skirmish", "name": "Skirmish", "map": map_id, "victory": "buildings",
		"players": players, "spawns": spawns,
	}
