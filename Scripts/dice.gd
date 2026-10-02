extends StaticBody2D

signal roll_done(index: int)

@onready var faces: Node2D = $faces
@onready var label: Label = $Label

var isRolling: bool = false
var currentIndex: int = 0

func _ready() -> void:
	set_start_face()
	label.text = ""
	# Connect the signal so _on_roll_done gets called when roll_done emits
	roll_done.connect(_on_roll_done)

func set_start_face() -> void:
	for face in faces.get_children():
		face.hide()
	if faces.get_child_count() > 0:
		faces.get_child(0).show()

# Connected to the input_event signal of StaticBody2D
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Check the event directly for a left mouse button press
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not isRolling:
			_roll_dice()

func _roll_dice() -> void:
	var duration: float = 1.0
	isRolling = true
	label.text = ""
	
	while duration > 0:
		var newIndex = faces.get_children().pick_random().get_index()
		faces.get_child(currentIndex).hide()
		faces.get_child(newIndex).show()
		
		# Fixed typo: changed creat_time to create_timer
		await get_tree().create_timer(0.1).timeout
		
		currentIndex = newIndex
		duration -= 0.1
	
	isRolling = false
	roll_done.emit(currentIndex + 1)

func _on_roll_done(index: int) -> void:
	label.text = str(index)
