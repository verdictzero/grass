extends CanvasLayer
## Title screen with bobbing title and start button

signal game_started

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var bg: ColorRect = $Background

var bob_time := 0.0

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	visible = true

func _process(delta: float) -> void:
	if not visible:
		return
	# Title bob animation (3s cycle, -8px offset)
	bob_time += delta
	if title_label:
		title_label.position.y = sin(bob_time * TAU / 3.0) * -8.0

func _on_start_pressed() -> void:
	visible = false
	Config.game_started = true
	game_started.emit()
