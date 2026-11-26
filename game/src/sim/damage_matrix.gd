class_name DamageMatrix
extends RefCounted
## Damage type x armor class -> percent of damage dealt (P1-09).
## Loaded from res://data/damage_matrix.json by ContentDb. Ints only.

## Which armor classes each weapon target category covers.
const TARGET_CATEGORIES: Dictionary = {
	"ground": ["infantry", "light_vehicle", "heavy_armor", "structure"],
	"air": ["aircraft"],
	"drone": ["drone"],
}

var armor_classes: PackedStringArray = []
var _percent: Dictionary[String, int] = {}   ## "damage_type/armor_class" -> percent


func set_percent(damage_type: String, armor_class: String, percent: int) -> void:
	_percent[damage_type + "/" + armor_class] = percent


func has_damage_type(damage_type: String) -> bool:
	return armor_classes.size() > 0 and _percent.has(damage_type + "/" + armor_classes[0])


## Percent for a pair. Unknown pairs deal 100% (tests and placeholder data).
func percent(damage_type: String, armor_class: String) -> int:
	return _percent.get(damage_type + "/" + armor_class, 100)


## Damage after armor. Never rounds a non-zero hit down to 0.
func apply(damage: int, damage_type: String, armor_class: String) -> int:
	var p: int = percent(damage_type, armor_class)
	if p <= 0 or damage <= 0:
		return 0
	return maxi(1, (damage * p) / 100)


static func can_target(categories: PackedStringArray, armor_class: String) -> bool:
	for c: String in categories:
		if (TARGET_CATEGORIES.get(c, []) as Array).has(armor_class):
			return true
	return false
