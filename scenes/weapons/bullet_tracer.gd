extends Node3D

func init_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	global_position = from_pos
	var distance: float = from_pos.distance_to(to_pos)
	if distance > 0.1:
		look_at(to_pos, Vector3.UP)
		scale.z = distance
	
	var tween = create_tween()
	tween.tween_property(self, "scale:x", 0.0, 0.06)
	tween.parallel().tween_property(self, "scale:y", 0.0, 0.06)
	tween.tween_callback(queue_free)

