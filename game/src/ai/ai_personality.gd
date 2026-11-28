class_name AiPersonality
extends RefCounted
## Skirmish AI personalities (P3-13b, docs/design/ai-opponent.md): overlays
## from game/data/ai/personalities.json on a faction preset, applied once
## before the AI's first decision. "random" is resolved from the AI's own
## seed (AiPlayer._seed), so every machine picks the same one. Also the
## difficulty overlay (P3-13a). Ints only.

const NAMES: Array[String] = ["balanced", "rusher", "turtle", "tech"]


static func apply(ai: AiPlayer, content: ContentDb, faction: String, personality: String) -> void:
	ai.personality = personality
	var p: Dictionary = content.ai_personalities.get(personality, {})
	ai.first_attack_tick = maxi(60 * SimWorld.TICK_RATE, ai.first_attack_tick + int(p.get("first_attack_shift_s", 0)) * SimWorld.TICK_RATE)
	ai.attack_wave_size = maxi(3, ai.attack_wave_size + int(p.get("wave_size_delta", 0)))
	ai.max_gatherers = maxi(2, ai.max_gatherers + int(p.get("max_gatherers_delta", 0)))
	ai.defend_radius += Fx.from_int(int(p.get("defend_radius_delta_m", 0)))
	match str(p.get("research", "")):
		"none":
			ai.research.clear()
		"all":
			var ids: Array = content.upgrades.keys()
			ids.sort()
			for id: String in ids:
				var up: UpgradeDef = content.upgrades[id]
				if up.faction == faction and up.scope == "global" and not up.granted and not ai.research.has(id):
					ai.research.append(id)
	if not bool(p.get("superweapon", true)):
		ai.superweapon = ""
	var boost: Dictionary = p.get("mix_boost", {})
	for u: String in ai.unit_mix.keys():
		var def: UnitDef = content.get_unit(u)
		if def != null and boost.has(def.armor_class):
			ai.unit_mix[u] *= int(boost[def.armor_class])
	var defenses: Array[String] = defensive_buildings(content, faction)
	for i: int in int(p.get("extra_defenses", 0)):
		for id: String in defenses:
			ai.build_order.append(id)


## Difficulty (P3-13a): easy thinks half as often, attacks later and bigger
## and skips counters and research; hard doesn't cheat on sight or income: it
## reacts faster, runs a bigger economy and attacks sooner.
static func apply_difficulty(ai: AiPlayer, level: String) -> void:
	ai.difficulty = level
	if level == "easy":
		ai.think_interval *= 2
		ai.attack_wave_size += 3
		ai.first_attack_tick += 60 * SimWorld.TICK_RATE
		ai.max_gatherers = maxi(2, ai.max_gatherers - 1)
		ai.counters.clear()
		ai.research.clear()
	elif level == "hard":
		ai.think_interval = maxi(1, (ai.think_interval * 2) / 3)
		ai.max_gatherers += 2
		ai.first_attack_tick = maxi(60 * SimWorld.TICK_RATE, ai.first_attack_tick - 30 * SimWorld.TICK_RATE)
		ai.attack_wave_size = maxi(3, ai.attack_wave_size - 1)


## The faction's buildings that only fight (bunkers, trenches, air-defense
## sites), sorted by id.
static func defensive_buildings(content: ContentDb, faction: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in content.buildings:
		var b: BuildingDef = content.buildings[id]
		if b.faction == faction and not b.weapons.is_empty() and b.produces.is_empty() and b.cost > 0:
			out.append(id)
	out.sort()
	return out
