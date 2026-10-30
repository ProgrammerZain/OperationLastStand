extends Node3D

@onready var particles: CPUParticles3D = $Sparks

func _ready() -> void:
	if particles:
		particles.emitting = true
	# Clean up after 2.5 seconds
	var timer = get_tree().create_timer(2.5)
	timer.timeout.connect(queue_free)

