extends Button

@onready var label = $RichTextLabel

func _ready():
	# Connect the built-in button signals to custom functions
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_exit)

func _on_hover():
	# Eerie fluorescent cyan (R, G, B)
	label.modulate = Color("dbd7bfff") 

func _on_exit():
	# Resets text back to default
	label.modulate = Color("d4d0b4")
