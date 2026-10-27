class_name TestCase
extends RefCounted
## Base class for headless unit tests. Methods named test_* are run by
## tests/run_tests.gd; a test fails if any assertion inside it fails.

var failures: PackedStringArray = PackedStringArray()


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


## Builds a model from rows of a single-layer-per-entry layout description.
func make_model(layers: Array, faces: PackedStringArray) -> BoardModel:
	var layout := BoardLayout.from_dict({"layers": layers})
	return BoardModel.new(layout.build_geometry(), faces)


## Index of the tile at half-unit position (x, y, z), or -1.
func tile_at(model: BoardModel, x: int, y: int, z: int) -> int:
	return model.geometry.positions.find(Vector3i(x, y, z))
