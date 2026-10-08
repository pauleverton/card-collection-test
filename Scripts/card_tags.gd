@tool
class_name CardTags
extends RefCounted
## The ONE list of card tags and types. Add new ones here and nowhere else:
## every dropdown (cards and players) reads from these.

const TAGS := ["pass", "dribble", "long_ball", "cross", "shot", "tackle",
		"track_back", "block", "overlap", "retain", "lump_clear"]
const TYPES := ["attacking", "defending", "move", "utility"]
