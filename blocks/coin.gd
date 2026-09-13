extends Node3D
class_name Coin

## Gold that bursts out of a dead goblin.
##
## No collision body and no Area3D: collection is a plain distance check. At
## 25 m/s you cover a third of a metre per physics tick, so an overlap test
## tunnels straight through a small pickup and the coin is silently missed.
## A distance check cannot tunnel.
##
## Coins also cannot be expected to land anywhere sensible -- they burst out
## over a channel with a hole down the middle -- so after a short arc they stop
## falling and hover where they are, bobbing, until collected or expired.

@export var value := 1
## Generous on purpose. Threading a 1m pickup while surfing is not a skill test.
@export var pickup_radius := 3.0
## Once you are this close the coin comes to you.
@export var magnet_range := 20.0
@export var magnet_speed := 75.0
@export var gravity := 22.0
## How long it arcs before it stops falling and hovers.
@export var arc_time := 0.7
@export var lifetime := 25.0

var velocity := Vector3.ZERO

var _age := 0.0
var _home := Vector3.ZERO
var _player: SurfPlayer = null
var _collected := false


func _ready() -> void:
	_home = global_position


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_age += delta
	if _age > lifetime:
		queue_free()
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as SurfPlayer

	if _player != null:
		var to_player := _player.global_position + Vector3(0, 0.9, 0) - global_position
		var distance := to_player.length()
		if distance < pickup_radius:
			_collect()
			return
		if distance < magnet_range:
			# Pulled straight to you, overriding the arc entirely.
			global_position += to_player.normalized() * magnet_speed * delta
			_spin(delta)
			return

	if _age < arc_time:
		velocity.y -= gravity * delta
		global_position += velocity * delta
		_home = global_position
	else:
		# Hover and bob where the arc left it.
		global_position = _home + Vector3(0, sin(_age * 3.0) * 0.35, 0)
	_spin(delta)


func _spin(delta: float) -> void:
	rotation.y += delta * 4.0


func _collect() -> void:
	_collected = true
	if _player != null:
		_player.collect_coin(value)
	# A quick pop so a pickup registers at speed.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 2.2, 0.12)
	tween.tween_property(self, "position:y", position.y + 1.5, 0.12)
	tween.chain().tween_callback(queue_free)


## Throw a coin out from a point with some spread.
static func burst(host: Node, at: Vector3, count: int, worth: int = 1) -> void:
	var scene: PackedScene = load("res://blocks/coin.tscn")
	for i in count:
		var coin: Coin = scene.instantiate()
		host.add_child(coin)
		coin.value = worth
		coin.global_position = at
		var angle := TAU * float(i) / float(count) + randf() * 0.6
		coin.velocity = Vector3(cos(angle), 0.0, sin(angle)) * randf_range(3.0, 7.0)
		coin.velocity.y = randf_range(6.0, 10.0)
