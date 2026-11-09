@tool
class_name CardTags
extends RefCounted
## The ONE list of card tags and types. Add new ones here and nowhere else:
## every dropdown (cards and players) reads from these.

const TAGS := ["pass", "dribble", "long_ball", "cross", "shot","shot_button", "tackle",
		"track_back", "block", "overlap", "retain", "lump_clear","switch",
		"long_shot","stepover","nutmeg","cruyff_turn"]
const TYPES := ["attacking", "defending", "move", "utility","skills"]
## One colour per type (card bands, players' and coaches' badges).
const TYPE_COLOURS := {"attacking": Color("c9302c"), "move": Color("2b5bc4"),
		"utility": Color("d9822b"), "defending": Color("2f7a3a"), "skills": Color("1f8a8a")}
