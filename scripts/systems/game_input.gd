extends Node
## 用代码注册输入映射。
## 这样避免手写 project.godot 里难读的 InputEvent 序列化文本，且一定生效。

func _ready() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT], [])
	_bind("move_right", [KEY_D, KEY_RIGHT], [])
	# W/↑ 留给爬梯，跳跃用空格/Z
	_bind("jump", [KEY_SPACE, KEY_Z], [])
	_bind("move_up", [KEY_W, KEY_UP], [])
	_bind("dash", [KEY_SHIFT], [])
	_bind("move_down", [KEY_S, KEY_DOWN], [])
	_bind("attack", [KEY_J, KEY_X], [MOUSE_BUTTON_LEFT])
	_bind("skill_1", [KEY_Q], [])
	_bind("skill_2", [KEY_E], [])
	_bind("interact", [KEY_F, KEY_ENTER], [])
	_bind("restart", [KEY_R], [])

func _bind(action: String, keys: Array, mouse_buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	else:
		InputMap.action_erase_events(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for mb in mouse_buttons:
		var e := InputEventMouseButton.new()
		e.button_index = mb
		InputMap.action_add_event(action, e)
