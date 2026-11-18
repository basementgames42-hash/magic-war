extends Node2D
# Epic FX: a one-off drawn effect for the Epic combos (a falling comet, a
# seal on the ground, a pillar of light...). Give it a painter and a
# lifetime; it redraws every frame and deletes itself when done.
#   EFX.spawn(parent, pos, 0.5, func(fx: Node2D, k: float): fx.draw_circle(...))
# k runs 0 -> 1 over the lifetime. Draw relative to the effect's position.

var painter: Callable
var lifetime: float = 0.5
var age: float = 0.0

static func spawn(parent: Node, pos: Vector2, life: float, paint: Callable, layer: int = 5) -> Node2D:
	var fx := preload("res://scenes/spells/epic_fx.gd").new()
	fx.painter = paint
	fx.lifetime = life
	fx.z_index = layer
	parent.add_child(fx)
	fx.global_position = pos
	return fx

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	painter.call(self, clampf(age / lifetime, 0.0, 1.0))
