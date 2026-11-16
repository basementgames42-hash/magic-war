extends Node2D
# Starfall: calls falling stars down on the thickest crowds near the player.
# Each star marks the ground, then blasts everything nearby. Levels add
# damage, blast size and, at levels 2 and 4, an extra star per volley.
#
# Targeting: each star picks the enemy with the most others around it (so
# one blast catches a crowd, not a straggler), aims where that enemy will be
# when the star lands, and later stars in the volley go to other crowds (or,
# in one big swarm, pile onto it too).

const STRIKE = preload("res://scenes/spells/starfall_strike.gd")
const BALANCE: Balance = preload("res://config/balance.tres")

@export var cooldown: float = 2.5
@export var strike_range: float = 520.0  # Roughly what's on screen around the player

var level: int = 1
var timer: float = 1.0

func set_level(new_level: int) -> void:
	level = new_level

func blast_radius() -> float:
	return 95.0 + 15.0 * (level - 1)

func star_count() -> int:
	return 1 + level / 2  # 1, 2, 2, 3, 3

func _process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	var targets: Array[Vector2] = pick_targets()
	if targets.is_empty():
		timer = 0.25  # Nothing in range: check again soon rather than wait a full cooldown
		return
	timer = cooldown
	for spot in targets:
		var strike: Node2D = STRIKE.new()
		strike.damage = BALANCE.starfall_damage + BALANCE.starfall_damage_per_level * (level - 1)
		strike.radius = blast_radius()
		strike.global_position = spot
		get_tree().current_scene.add_child(strike)

func pick_targets() -> Array[Vector2]:
	var radius: float = blast_radius()
	var near: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < strike_range:
			near.append(enemy)
	var spots: Array[Vector2] = []
	for i in star_count():
		var best: Node2D = null
		var best_count: int = -1
		for enemy in near:
			# Lead the target: where it'll be when the star lands.
			var aim: Vector2 = enemy.global_position + enemy.velocity * STRIKE.DROP_TIME
			if spots.any(func(s): return s.distance_to(aim) < radius):
				continue  # An earlier star already covers this crowd
			var count: int = 0
			for other in near:
				if other.global_position.distance_to(aim) < radius:
					count += 1
			if count > best_count:
				best_count = count
				best = enemy
		if best == null:
			if spots.is_empty():
				break  # No enemies in range
			# Every crowd is covered (one big swarm): stack this star on the
			# biggest one rather than waste it.
			spots.append(spots[0] + Vector2.from_angle(randf() * TAU) * radius * 0.4)
			continue
		spots.append(best.global_position + best.velocity * STRIKE.DROP_TIME)
	return spots
