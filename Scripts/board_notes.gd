class_name BoardNotes
extends RefCounted
## The manager's scrawls on the team sheet whiteboard: which notes apply right now.
## Rules only, no visuals: TacticsBoard writes whatever pick() returns.
##
## NOTES is the text. Add, change or delete lines freely. Each note has:
##   when      the situation it's for (the full list is in _applies, at the bottom)
##   text      what's written. A list of texts = one is picked at random each time.
##             {opponent}, {pts} ("1 pt" / "3 pts" off the top) and {name} are filled in.
##   colour    "blue", "red" or "black"
##   priority  higher wins when more notes apply than fit; also the order they're written in
##   style     optional: "marker" = big block letters, otherwise handwriting
##   player    optional: a player's file name (e.g. "kitchen_sink"): only shown if you own
##             him and he has games left this season; {name} = his name
## when "player_last_game" is special: one note for each player down to his last game
## while the favourites are still to come (after this match).
## Rule for writing notes: every note must be TRUE by the game's rules, or players learn
## to ignore the board.

const MAX_NOTES := 5

const NOTES := [
	## ----- The match -----
	{"when": "first_game", "text": ["First game of the season. Start strong!", "New season. Fresh start."],
		"colour": "blue", "priority": 5},
	{"when": "last_game", "text": "LAST GAME!", "colour": "red", "priority": 12, "style": "marker"},
	{"when": "last_game_behind", "text": "{pts} behind the leaders.", "colour": "blue", "priority": 11},
	{"when": "last_game_behind", "text": "WIN IT!", "colour": "red", "priority": 10, "style": "marker"},
	{"when": "last_game_behind", "text": ["Can't be too defensive!", "Have to go for it."],
		"colour": "blue", "priority": 9},
	{"when": "last_game_out_of_reach", "text": "Can't catch them now. Play for pride.", "colour": "blue", "priority": 11},
	{"when": "last_game_top", "text": "Top going into the last game.", "colour": "blue", "priority": 11},
	{"when": "last_game_top_clear", "text": "Win and the league's ours!", "colour": "red", "priority": 10},
	{"when": "chasing", "text": ["{pts} off the top. Can't drop more.", "{pts} off the top. Need points."],
		"colour": "blue", "priority": 6},
	{"when": "top", "text": ["Top of the league. Keep it going!", "Top spot. Don't get complacent."],
		"colour": "blue", "priority": 6},

	## ----- Them -----
	{"when": "favourites", "text": "FAVOURITES", "colour": "red", "priority": 9, "style": "marker"},
	{"when": "favourites", "text": "A quarter tougher than anyone else.", "colour": "red", "priority": 8},
	{"when": "attack_high", "text": ["Dangerous up front. Bodies back?", "They'll come at us. Who's tracking back?"],
		"colour": "red", "priority": 7},
	{"when": "attack_low", "text": "Not much threat up front.", "colour": "blue", "priority": 3},
	{"when": "defence_high", "text": ["They press high. Keep it simple.", "Hard to break down. Be patient."],
		"colour": "blue", "priority": 6},
	{"when": "defence_low", "text": ["Soft at the back. Run at them!", "Weak defence. Risk an extra pass in the box."],
		"colour": "blue", "priority": 6},
	{"when": "keeper_high", "text": ["Keeper's a wall. Work a better chance.", "Top keeper. Don't waste shots."],
		"colour": "blue", "priority": 5},
	{"when": "keeper_low", "text": ["Keeper's shaky. Shoot on sight!", "Dodgy keeper. Get shots off."],
		"colour": "blue", "priority": 5},

	## ----- Your players -----
	{"when": "player_last_game", "text": "Save {name} for the favourites?", "colour": "blue", "priority": 8},
	{"when": "any", "player": "kitchen_sink", "text": "{name} if we're losing at 60'?", "colour": "blue", "priority": 4},
	{"when": "any", "player": "park_the_bus", "text": "{name} if we're ahead at 60'?", "colour": "blue", "priority": 4},
	{"when": "any", "player": "super_sub", "text": "{name} for a late winner (75'+)?", "colour": "blue", "priority": 4},
]

## The notes to write, most important first, each with its text filled in.
static func pick() -> Array:
	var candidates: Array = []
	for note in NOTES:
		if note["when"] == "player_last_game":
			for p in _players_to_save():
				candidates.append(_fill(note, p.display_name))
		elif note.has("player"):
			var p := _owned_player(note["player"])
			if p != null and _applies(note["when"]):
				candidates.append(_fill(note, p.display_name))
		elif _applies(note["when"]):
			candidates.append(_fill(note, ""))
	candidates.sort_custom(func(a, b): return a["priority"] > b["priority"])
	return candidates.slice(0, MAX_NOTES)

## Points between you and the best other team (negative = you're ahead).
static func points_off_top() -> int:
	var best := -1
	for i in range(1, LeagueState.table.size()):
		best = maxi(best, LeagueState.table[i]["points"])
	return best - LeagueState.your_points()

## A copy of the note with one text chosen and the {placeholders} filled in.
static func _fill(note: Dictionary, player_name: String) -> Dictionary:
	var text = note["text"]
	if text is Array:
		text = text.pick_random()
	var them := LeagueState.next_opponent()
	var off := points_off_top()
	text = text.replace("{name}", player_name)
	text = text.replace("{opponent}", them.team_name if them != null else "them")
	text = text.replace("{pts}", "1 pt" if off == 1 else "%d pts" % off)
	var filled := note.duplicate()
	filled["text"] = text
	return filled

## A player you own (by file name) who still has games left, or null.
static func _owned_player(file_name: String) -> PlayerCard:
	for p in RunState.players():
		if p.resource_path.get_file().get_basename() == file_name and LeagueState.appearances_left(p) > 0:
			return p
	return null

## Players down to their last game while the favourites are still to come (after this match).
static func _players_to_save() -> Array:
	var favourites_later := false
	for f in LeagueState.your_fixtures():
		if f["round"] - 1 > LeagueState.matches_played and f["team"] != null and f["team"].is_favourite:
			favourites_later = true
	if not favourites_later:
		return []
	return RunState.players().filter(func(p): return LeagueState.appearances_left(p) == 1)

static func _high(rating: float) -> bool:
	return rating > 1.0 and not is_equal_approx(rating, 1.0)

static func _low(rating: float) -> bool:
	return rating < 1.0 and not is_equal_approx(rating, 1.0)

## The situations. A new kind of situation = one line here, then notes for it in NOTES.
static func _applies(when: String) -> bool:
	var them := LeagueState.next_opponent()
	var played := LeagueState.matches_played
	var off := points_off_top()
	var top := LeagueState.position_of(LeagueState.YOU) == 1
	var last := LeagueState.matches_remaining() == 1
	match when:
		"any": return true
		"first_game": return played == 0
		"last_game": return last
		"last_game_behind": return last and off >= 1 and off <= 3      ## a win can still do it
		"last_game_out_of_reach": return last and off > 3              ## +3 can't close the gap
		"last_game_top": return last and top
		"last_game_top_clear": return last and off < 0                 ## a point clear: a win is enough
		"chasing": return not last and played > 0 and off > 0
		"top": return not last and played > 0 and top
		"favourites": return them != null and them.is_favourite
		"attack_high": return them != null and _high(them.attack)
		"attack_low": return them != null and _low(them.attack)
		"defence_high": return them != null and _high(them.defence)
		"defence_low": return them != null and _low(them.defence)
		"keeper_high": return them != null and _high(them.keeper)
		"keeper_low": return them != null and _low(them.keeper)
	push_warning("BoardNotes: unknown situation \"%s\"" % when)
	return false
