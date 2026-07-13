extends VBoxContainer

@onready var card_texture = $CardBase/TextureRect

const CARDS = [
	"james_garner_bronze",
	"jake_obrien_bronze",
	"iliman_ndiaye_silver",
	"jordan_pickford_gold"
]

func _ready() -> void:
	card_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func load_random_card() -> void:
	var random_card = CARDS[randi() % CARDS.size()]
	print("loading card: ", random_card)
	load_card(random_card)

func load_card(card_name: String) -> void:
	var texture = load("res://Cards/" + card_name + ".png")
	print("texture loaded: ", texture)
	card_texture.texture = texture
	
func _on_button_pressed() -> void:
	print("button pressed")
	load_random_card()
