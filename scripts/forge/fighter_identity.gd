class_name FighterIdentity
extends RefCounted
## Local identity rules choose game-owned abilities without changing accepted art.

const KITS := ["ember", "frost", "storm", "stone", "nature", "shadow"]
const MAGIC_WORDS := r"\b(wizards?|mages?|archmages?|sorcerers?|sorceress(?:es)?|witch(?:es)?|necromancers?|warlocks?|druids?|shamans?|magicians?|spellcasters?|spellblades?|battlemages?|casters?|clerics?|priests?|enchanters?|enchantress(?:es)?|elementalists?|illusionists?|psychics?|witchdoctors?|magic|magical|arcane)\b"
const PHYSICAL_WORDS := r"\b(swords?|swordsman|swordsmen|swordfighters?|spears?|spearman|spearmen|lancers?|blades?|axes?|hammers?|maces?|daggers?|rapiers?|halberds?|pikes?|tridents?|scythes?|katanas?|knights?|warriors?|soldiers?|samurai|ronin|fencers?|duelists?|berserkers?|assassins?|rogues?|ninjas?|brawlers?|boxers?|monks?|paladins?|gladiators?|shields?|sabres?|sabers?|scimitars?|fighters?)\b"
const NATURE_WORDS := r"\b(druids?|shamans?|nature|plants?|flora|forest|vines?|thorns?|roots?)\b"
const EMBER_WORDS := r"\b(ember|fire|flame|flaming|burning)\b"
const STORM_WORDS := r"\b(storm|lightning|thunder)\b"


static func attack_style(name: String, description: String = "") -> String:
	var identity_name := "" if name.strip_edges().to_lower() == "my fighter" else name
	var text := (identity_name + " " + description).to_lower()
	# A spellblade or sword-carrying wizard remains a caster.
	if _matches(text, MAGIC_WORDS):
		return "magic"
	if _matches(text, PHYSICAL_WORDS):
		return "physical"
	return ""


static func suggested_kit(name: String, description: String = "") -> String:
	var text := (name + " " + description).to_lower()
	match attack_style(name, description):
		"magic":
			return "nature" if _matches(text, NATURE_WORDS) else "frost"
		"physical":
			if _matches(text, EMBER_WORDS):
				return "ember"
			if _matches(text, STORM_WORDS):
				return "storm"
			return "stone"
	return ""


static func effective_kit(name: String, requested: String, description: String = "") -> String:
	var kit := requested.strip_edges().to_lower()
	match attack_style(name, description):
		"magic":
			return kit if kit in ["frost", "nature"] else suggested_kit(name, description)
		"physical":
			return kit if kit in ["ember", "storm", "stone"] else suggested_kit(name, description)
	return kit if kit in KITS else "ember"


static func resolve(bundle: Dictionary) -> String:
	var name: Variant = bundle.get("name", "")
	var requested: Variant = bundle.get("kit_id", "ember")
	return effective_kit(name if name is String else "", requested if requested is String else "ember")


static func _matches(text: String, pattern: String) -> bool:
	var regex := RegEx.new()
	return regex.compile(pattern) == OK and regex.search(text) != null
