extends PanelContainer
class_name BattleCardSlot

## One card slot in the battle arena. The SAME script is used for both the
## player's column and the opponent's column — `side` (set per-node in
## match.tscn) decides the behaviour:
##
##   side == "player"   -> drag SOURCE (pick this card up to attack with it)
##                          also a drop TARGET for the consumable icon
##                          (drag boots onto a player to boost their next shot)
##   side == "opponent" -> drop TARGET only (drop a player card here to
##                          attack this opponent)
##
## match.gd listens to attack_dropped / consumable_dropped and drives the
## actual match logic — this script only handles the drag gesture + visuals.

signal attack_dropped(attacker_id: String, target_slot: BattleCardSlot)
signal consumable_dropped(consumable_id: String, target_slot: BattleCardSlot)
signal drag_started(from_slot: BattleCardSlot)

@export_enum("player", "opponent") var side: String = "player"

@onready var texture_rect: TextureRect = $Margin/VBox/TextureRect
@onready var name_label: Label = $Margin/VBox/NameLabel

var card_id: String = ""
var interactive: bool = true
var boosted: bool = false

const NORMAL_COLOR := Color(1, 1, 1, 1)
const LOCKED_COLOR := Color(1, 1, 1, 0.4)
const VALID_TARGET_COLOR := Color(1, 0.85, 0.35, 1)
const BOOSTED_COLOR := Color(0.55, 1, 0.65, 1)
const SCORE_FLASH_COLOR := Color(0.35, 1, 0.45, 1)
const MISS_FLASH_COLOR := Color(1, 0.35, 0.35, 1)


func _ready() -> void:
	mouse_exited.connect(_refresh_color)


func set_card(id: String) -> void:
	card_id = id
	visible = id != ""
	if id == "":
		texture_rect.texture = null
		name_label.text = ""
		return

	var card: CardData = CardDatabase.get_card(id)
	if card == null:
		texture_rect.texture = null
		name_label.text = id
		return

	texture_rect.texture = card.texture
	name_label.text = card.display_name if card.display_name != "" else id
	_refresh_color()


func set_interactive(value: bool) -> void:
	interactive = value
	_refresh_color()


func set_boosted(value: bool) -> void:
	boosted = value
	_refresh_color()


func flash_result(scored: bool) -> void:
	var flash_color := SCORE_FLASH_COLOR if scored else MISS_FLASH_COLOR
	var tween := create_tween()
	tween.tween_property(self, "modulate", flash_color, 0.1)
	tween.tween_property(self, "modulate", NORMAL_COLOR, 0.5)
	await tween.finished
	_refresh_color()


func _refresh_color() -> void:
	if not interactive:
		modulate = LOCKED_COLOR
	elif boosted:
		modulate = BOOSTED_COLOR
	else:
		modulate = NORMAL_COLOR


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not interactive or card_id == "" or side != "player":
		return null

	var preview := TextureRect.new()
	preview.texture = texture_rect.texture
	preview.custom_minimum_size = Vector2(70, 100)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	drag_started.emit(self)
	return {"type": "attack", "attacker_id": card_id}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not interactive or card_id == "" or typeof(data) != TYPE_DICTIONARY:
		return false

	if side == "opponent" and data.get("type") == "attack":
		modulate = VALID_TARGET_COLOR
		return true
	if side == "player" and data.get("type") == "consumable":
		modulate = VALID_TARGET_COLOR
		return true
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.get("type") == "attack":
		attack_dropped.emit(data.attacker_id, self)
	elif data.get("type") == "consumable":
		consumable_dropped.emit(data.consumable_id, self)
	_refresh_color()


func _notification(what: int) -> void:
	# Fires on every Control when a drag ends anywhere, regardless of
	# whether THIS slot was the drop target — resets the hover highlight
	# left over from _can_drop_data if the drop happened elsewhere.
	if what == NOTIFICATION_DRAG_END:
		_refresh_color()
