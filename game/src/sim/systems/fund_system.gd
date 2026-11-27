class_name FundSystem
extends RefCounted
## The UAE's sovereign fund (P3-02b, docs/design/factions.md): every
## rules.fund_interval_ticks, a player of rules.fund_faction earns
## rules.fund_percent of their unspent credits, at most rules.fund_cap (twice
## that once they chose the rules.fund_cap_doubler unlock). Saving pays off,
## but the cap keeps hoarding from snowballing. Players in id order.


static func step(world: SimWorld) -> void:
	var r: SimRules = world.rules
	if r.fund_faction == "" or r.fund_interval_ticks <= 0 or world.tick == 0 or world.tick % r.fund_interval_ticks != 0:
		return
	var ids: Array[int] = []
	for pid: int in world.players:
		ids.append(pid)
	ids.sort()
	for pid: int in ids:
		var p: SimPlayer = world.players[pid]
		if p.faction != r.fund_faction or p.defeated:
			continue
		var gain: int = mini((p.credits * r.fund_percent) / 100, cap_for(world, p))
		if gain > 0:
			p.credits += gain
			world.events.append({"type": "interest", "player": pid, "amount": gain})


## The most one payment can be for this player.
static func cap_for(world: SimWorld, p: SimPlayer) -> int:
	var cap: int = world.rules.fund_cap
	if world.rules.fund_cap_doubler != "" and p.powers.has(world.rules.fund_cap_doubler):
		cap *= 2
	return cap
