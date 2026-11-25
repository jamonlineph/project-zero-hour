# Coding standards

## GDScript style

- **Godot 4.7, GDScript 2.0.** Use static typing everywhere: `var hp: int = 0`, `func step(world: SimWorld) -> void:`. Use `:=` only when the type is obvious from the right-hand side.
- **Typed collections:** `Array[int]`, `Array[SimEntity]`, `Dictionary[int, SimEntity]`. Nested typed collections aren't supported, so use `Dictionary[int, Array]` and comment the element type.
- **Names:**
  - files: `snake_case.gd`
  - classes: `PascalCase`, declared with `class_name`
  - functions and variables: `snake_case`
  - constants: `UPPER_SNAKE`
  - private members: `_leading_underscore`
  - signals: past tense (`selection_changed`)
- **One class per file.** Keep files under about 400 lines.
- **Comments:** `##` doc comments on classes and public functions say what and why, not how. Mention units (fixed-point meters, ticks).
- **No magic numbers.** Use named constants, or data in JSON.
- **Errors:** use `push_error()` with a clear message, then fall back safely. Don't crash the game for bad data; report it.
- **Indentation:** tabs, as Godot's editor uses.
- **No autoloads (singletons)** unless an ADR approves one. Pass dependencies explicitly (see `main.gd`).

## Godot 3 → Godot 4 pitfalls

AI models often produce Godot 3 code. Use the right column only.

| ❌ Godot 3 | ✅ Godot 4.7 |
|---|---|
| `onready var x` / `export var x` / `tool` | `@onready var x` / `@export var x` / `@tool` |
| `yield(obj, "sig")` | `await obj.sig` |
| `connect("sig", self, "_on_sig")` | `sig.connect(_on_sig)` |
| `emit_signal("sig", a)` | `sig.emit(a)` |
| `scene.instance()` | `scene.instantiate()` |
| `Spatial`, `KinematicBody`, `RigidBody`, `Area` | `Node3D`, `CharacterBody3D`, `RigidBody3D`, `Area3D` |
| `node.translation` | `node.position` |
| `PoolStringArray`, `PoolIntArray` | `PackedStringArray`, `PackedInt32Array` / `PackedInt64Array` |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` (view/UI only, never in the sim) |
| `rand_range(a, b)` | `randf_range(a, b)` (view only; the sim uses `SimRng`) |
| `File.new()` / `Directory.new()` | `FileAccess.open(...)` / `DirAccess.open(...)` |
| `JSON.parse(text).result` | `JSON.parse_string(text)`, or `JSON.new().parse(text)` then `.data` |
| `get_tree().change_scene("...")` | `get_tree().change_scene_to_file("...")` |
| `deg2rad`, `rad2deg`, `stepify` | `deg_to_rad`, `rad_to_deg`, `snapped` |
| `Engine.editor_hint` | `Engine.is_editor_hint()` |
| `funcref(self, "m")` | `m` (a `Callable`) or `Callable(self, "m")` |
| `str2var` / `var2str` | `str_to_var` / `var_to_str` |
| `remote func`, `is_network_master()` | `@rpc func`, `is_multiplayer_authority()` |
| `var x setget set_x` | `var x: int: set = _set_x` |

## Determinism checklist (anything in `src/sim/`)

- [ ] No `float` literals or variables. Use `Fx.from_ratio(1, 2)`, not `0.5`.
- [ ] No `Vector2`, `Vector3`, `Transform3D`, `Basis` or `Quaternion`.
- [ ] No `randi`, `randf`, `RandomNumberGenerator`, `Time`, `OS`, `Engine`, `get_tree()` or `Node`.
- [ ] Loops over entities use `world.entity_ids`. Any other collection is sorted before order matters.
- [ ] New state is included in a `write_hash()`.
- [ ] Integer multiplications of two fixed values stay within `Fx.MAX_ABS`.
- [ ] A test proves two runs with the same seed and commands give the same hashes.

## Tests

- Put unit tests in `game/tests/unit/test_<area>.gd`. Extend `TestCase` and name methods `test_<behavior>`.
- Use `assert_eq`, `assert_true`, `assert_false` and `assert_ne`. Don't use Godot's `assert()`.
- Tests must be fast (whole suite under 30 s) and must not depend on rendering.
- Every bug fix gets a test that would have caught it.
- The smoke test (`tests/smoke_main.gd`) must keep passing. Extend it when you add main-scene features.

## Commits and branches

- Commit message format: `<type>(<area>): <summary> [<TASK-ID>]`.
  - Types: `feat`, `fix`, `test`, `docs`, `refactor`, `perf`, `art`, `chore`.
  - Areas: `sim`, `view`, `input`, `ui`, `data`, `art`, `tools`, `docs`, `ci`.
- Make small commits that build and pass the tests.
- Branch name: `task/<ID>-<short-name>`. Do one task per pull request.
