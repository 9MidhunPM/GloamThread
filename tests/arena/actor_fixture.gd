extends Node2D
## Controlled arena coordinator fixture. No wallets or wave progression.
var phase := "combat"
var fighters: Array = []
var enemies: Array = []
var combat_root: Node2D
var effect_root: Node2D
var platforms: Array = []
var enemy_textures := {}
var hits: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var fighter_hits: Array[int] = []

func _ready() -> void:
	combat_root = self
	effect_root = self

func hit_enemies(rect: Rect2, damage: float, slot: int, attack_id: int, tags: Dictionary) -> int:
	hits.append({"rect":rect,"damage":damage,"slot":slot,"id":attack_id,"tags":tags.duplicate(true)})
	var count := 0
	for enemy: Node in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and rect.intersects(enemy.get_hurt_rect()):
			if enemy.take_damage(damage, slot, attack_id, tags): count += 1
	return count

func spawn_projectile(at: Vector2, direction: Vector2, damage: float, slot: int, tags: Dictionary) -> void:
	shots.append({"at":at,"direction":direction,"damage":damage,"slot":slot,"tags":tags.duplicate(true)})
	var projectile := ArenaProjectile.new()
	projectile.setup(self, at, direction, damage, slot, tags)
	add_child(projectile)

func effect(_at: Vector2, _color: Color, _kind: String) -> void:
	pass

func on_fighter_hit(slot: int) -> void:
	fighter_hits.append(slot)

func floor_body() -> StaticBody2D:
	return box(Vector2(320,330), Vector2(640,20))

func box(at: Vector2, size: Vector2, one_way: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.one_way_collision = one_way
	body.add_child(collision)
	if one_way: body.add_to_group("arena_one_way")
	add_child(body)
	return body
