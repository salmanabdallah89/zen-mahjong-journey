extends SceneTree
## Headless test runner. Usage:
##   godot --headless --path . -s res://tests/run_tests.gd
## Runs every test_* method in res://tests/unit/test_*.gd and exits with a
## non-zero code if any test fails.

const TEST_DIR := "res://tests/unit/"


func _initialize() -> void:
	var passed := 0
	var failed := 0
	var files := Array(DirAccess.get_files_at(TEST_DIR))
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load(TEST_DIR + file)
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var test_case: TestCase = script.new()
			var started := Time.get_ticks_msec()
			test_case.call(method_name)
			var elapsed := Time.get_ticks_msec() - started
			if test_case.failures.is_empty():
				passed += 1
				print("  PASS  %s.%s (%d ms)" % [file.get_basename(), method_name, elapsed])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [file.get_basename(), method_name])
				for failure in test_case.failures:
					print("        - " + failure)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
