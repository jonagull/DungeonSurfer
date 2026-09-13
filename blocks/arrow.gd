extends Area3D
class_name GoblinArrow

## An arrow loosed by a goblin archer.
##
## Hitting the player costs speed rather than health. Speed is the resource this
## whole game runs on -- lose enough and you slide off the ramp on your own --
## so draining it is both the punishment and the threat, and it never yanks
## control away the way a stun or a knockback would. Flow survives.

## Fraction of horizontal speed removed on a hit.
@export var speed_drain := 0.22
@export var speed := 48.0
@export var lifetime := 7.0

var _age := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += -global_basis.z * speed * delta
	_age += delta
	if _age > lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	# Arrows pass straight through goblins, so archers never shoot each other
	# (or themselves) and you never lose speed to a stray from off screen.
	if body is GoblinArcher:
		return
	if body is SurfPlayer:
		(body as SurfPlayer).take_hit(speed_drain)
	queue_free()
