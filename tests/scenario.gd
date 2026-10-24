class_name Scenario
extends Node
## Base for integration scenarios. Parent temporary game nodes beneath this
## node so the runner can dispose of the entire scenario after each result.

var failures: Array[String] = []


## Long real-time routes may declare a larger bound; CLI overrides still win.
func timeout_seconds() -> int:
	return 30


func run() -> void:
	assert_true(false, "Scenario must implement run()")


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func ticks(count: int) -> void:
	if count < 0:
		assert_true(false, "ticks() requires a nonnegative count")
		return
	for _index in count:
		await get_tree().physics_frame
