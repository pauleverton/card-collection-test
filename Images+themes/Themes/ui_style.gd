class_name UiStyle
extends RefCounted
## Shared button looks, so every screen matches.
##   UiStyle.primary(button)   = THE main action on a screen (Kick off, Play next match, Continue)
##   UiStyle.secondary(button) = everything else (Reroll, Shop, Back to hub...)
## Change a colour here and every button in the game follows.

const PRIMARY := Color("f2c14e")             ## gold
const PRIMARY_TEXT := Color("1b2a22")        ## dark green text on gold
const SECONDARY := Color("2a3d32")           ## dark green
const SECONDARY_TEXT := Color(0.92, 0.92, 0.92)
const SECONDARY_BORDER := Color(0.45, 0.55, 0.48)
const FOCUS_BORDER := Color.WHITE

static func primary(button: Button) -> void:
	_style(button, PRIMARY, PRIMARY_TEXT, PRIMARY)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 64)
	button.add_theme_font_size_override("font_size", 28)

static func secondary(button: Button) -> void:
	_style(button, SECONDARY, SECONDARY_TEXT, SECONDARY_BORDER)

## One box per button state: normal, hover (lighter), pressed (darker),
## disabled (dim), focus (just an outline, drawn on top of the others).
static func _style(button: Button, fill: Color, text: Color, border: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = border
		box.set_border_width_all(2)
		box.set_corner_radius_all(8)
		box.content_margin_left = 20
		box.content_margin_right = 20
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		match state:
			"hover":
				box.bg_color = fill.lightened(0.15)
			"pressed":
				box.bg_color = fill.darkened(0.15)
			"disabled":
				box.bg_color = fill.darkened(0.45)
				box.border_color = border.darkened(0.45)
			"focus":
				box.draw_center = false          ## outline only
				box.border_color = FOCUS_BORDER
		button.add_theme_stylebox_override(state, box)
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(colour_name, text)
	button.add_theme_color_override("font_disabled_color", Color(text, 0.5))
