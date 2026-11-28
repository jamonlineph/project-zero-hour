class_name MatchConfig
extends RefCounted
## Hands the menu's choices to the game scene (P1-32), and builds skirmish
## scenarios from them. A static variable instead of an autoload, per the
## "no autoloads" coding standard.

## Scenario dictionary for the next match (see MatchSetup), or empty.
static var pending: Dictionary = {}
## A save (SaveGame.read) to load instead of a new match (P3-22), or empty.
static var load_save: Dictionary = {}
## The LAN session for the next match and its seed (P3-14a), or null.
static var net: NetSession = null
static var net_seed: int = 0
## Faction ids that are playable in skirmish, with display names
## (docs/design/factions.md).
const FACTIONS: Dictionary = {"us": "America", "ae": "UAE", "kp": "North Korea", "eu": "EU"}


## The opponent picked when none is given: North Korea, or America for a
## North Korean player.
static func default_enemy(faction: String) -> String:
	return "us" if faction == "kp" else "kp"


## A LAN 1v1 (P3-14a): two humans, no AI; player 1 hosts.
static func lan(content: ContentDb, map_id: String, host_faction: String, client_faction: String, credits: int) -> Dictionary:
	var sc: Dictionary = skirmish(content, map_id, host_faction, credits, false, "normal", client_faction)
	(sc["players"] as Array)[1].erase("ai")
	(sc["players"] as Array)[1].erase("difficulty")
	sc["id"] = "lan"
	sc["name"] = "LAN game"
	return sc


## A 1v1 skirmish: player 1 (human, or AI when watching) against an AI.
## `enemy` is the computer's faction (default_enemy when empty); a mirror
## match (same faction) is allowed.
static func skirmish(content: ContentDb, map_id: String, faction: String, credits: int, watch_only: bool = false,
		difficulty: String = "normal", enemy: String = "", personality: String = "balanced") -> Dictionary:
	var map: MapDef = content.get_map(map_id)
	if enemy == "":
		enemy = default_enemy(faction)
	var players: Array = [
		{"id": 1, "team": 1, "faction": faction, "credits": credits},
		{"id": 2, "team": 2, "faction": enemy, "credits": credits, "ai": enemy + "_default", "difficulty": difficulty,
			"personality": personality},
	]
	if watch_only:
		players[0]["ai"] = faction + "_default"
		players[0]["difficulty"] = "normal"
	return {
		"id": "skirmish", "name": "Skirmish", "map": map_id, "victory": "buildings",
		"players": players, "spawns": _start_kits(content, map, players),
	}


## A 2v2 skirmish (P3-23b) on a map with four start positions: you (player
## 1) and a computer ally of your faction (player 3) against two computers
## of `enemy`'s faction (players 2 and 4). Player n starts at start n, so on
## a mirrored 2v2 map the odd players are west and the even ones east.
static func skirmish_2v2(content: ContentDb, map_id: String, faction: String, credits: int, watch_only: bool = false,
		difficulty: String = "normal", enemy: String = "", personality: String = "balanced") -> Dictionary:
	var map: MapDef = content.get_map(map_id)
	if enemy == "":
		enemy = default_enemy(faction)
	var players: Array = []
	for pid: int in [1, 2, 3, 4]:
		var mine: bool = pid % 2 == 1
		var p: Dictionary = {"id": pid, "team": 1 if mine else 2, "faction": faction if mine else enemy, "credits": credits}
		if pid == 3 or (pid == 1 and watch_only):
			p["ai"] = faction + "_default"
			p["difficulty"] = "normal"
		elif not mine:
			p["ai"] = enemy + "_default"
			p["difficulty"] = difficulty
			p["personality"] = personality
		players.append(p)
	return {
		"id": "skirmish", "name": "Skirmish 2v2", "map": map_id, "victory": "buildings",
		"players": players, "spawns": _start_kits(content, map, players),
	}


## Each player's starting units (rules start_kit) at its start position:
## player n at start n, mirrored for starts on the east half.
static func _start_kits(content: ContentDb, map: MapDef, players: Array) -> Array:
	var spawns: Array = []
	for slot: int in players.size():
		var f: String = players[slot]["faction"]
		var start: Vector2i = map.start_positions[slot] if slot < map.start_positions.size() else Vector2i(20 + slot * 80, 50)
		var mirror: int = -1 if start.x > map.width_m / 2 else 1
		for item: Variant in content.start_kit:
			var kit: Array = item
			spawns.append({
				"def": str(kit[0]).replace("{f}", f), "player": int(players[slot]["id"]),
				"x_m": start.x + int(kit[1]) * mirror, "y_m": start.y + int(kit[2]),
				"facing_deg": 0 if mirror > 0 else 180,
			})
	return spawns
