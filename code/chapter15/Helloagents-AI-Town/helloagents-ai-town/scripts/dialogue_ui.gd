# 对话UI脚本
extends CanvasLayer

# 节点引用
@onready var panel: Panel = $Panel
@onready var npc_name_label: Label = $Panel/NPCName
@onready var npc_title_label: Label = $Panel/NPCTitle
@onready var dialogue_text: RichTextLabel = $Panel/DialogueText
@onready var player_input: LineEdit = $Panel/PlayerInput
@onready var send_button: Button = $Panel/SendButton
@onready var close_button: Button = $Panel/CloseButton

# 当前对话的NPC
var current_npc_name: String = ""

# API客户端引用
var api_client: Node = null

# 防止重复发送消息的标志
var is_sending: bool = false

func _ready():
	# 添加到对话系统组
	add_to_group("dialogue_system")

	# 初始隐藏
	visible = false

	# 禁用LineEdit的清除按钮，防止干扰输入
	player_input.clear_button_enabled = false

	# 连接按钮信号
	send_button.pressed.connect(_on_send_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	player_input.text_submitted.connect(_on_text_submitted)

	# 连接输入框变化信号用于调试
	player_input.text_changed.connect(_on_text_changed)

	# 获取API客户端
	api_client = get_node_or_null("/root/APIClient")
	if api_client:
		api_client.chat_response_received.connect(_on_chat_response_received)
		api_client.chat_error.connect(_on_chat_error)

	print("[INFO] 对话UI初始化完成")
	print("[DEBUG] LineEdit text_submitted 信号已连接")
	print("[DEBUG] LineEdit clear_button已禁用")

# ⭐ 处理对话框快捷键
func _input(event: InputEvent):
	# 如果对话框不可见,不处理
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# ESC键 - 关闭对话框
		if event.keycode == KEY_ESCAPE:
			hide_dialogue()
			get_viewport().set_input_as_handled()
			print("[DEBUG] ESC键关闭对话框")
			return

		# 回车键 - 发送消息 (仅当输入框有焦点时通过text_submitted处理)
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			print("[DEBUG] 回车键被按下，输入框焦点状态: ", player_input.has_focus())
			# 如果输入框有焦点，让LineEdit的text_submitted信号处理
			if player_input.has_focus():
				print("[DEBUG] 输入框有焦点，等待text_submitted信号处理")
				return
			# 否则手动发送
			send_message()
			get_viewport().set_input_as_handled()
			print("[DEBUG] 回车键处理完成")
			return

		# 对于WASD、E、空格键，如果输入框有焦点，完全不处理
		# 这样可以避免任何可能的干扰
		if event.keycode in [KEY_E, KEY_SPACE, KEY_W, KEY_A, KEY_S, KEY_D]:
			if player_input.has_focus():
				print("[DEBUG] 输入框有焦点，完全忽略按键: ", char(event.keycode) if event.keycode <= 255 else str(event.keycode))
				# 完全不处理，让LineEdit和UI系统正常处理
				return

			# 只有在输入框无焦点时才屏蔽这些键
			get_viewport().set_input_as_handled()
			# 只在第一次屏蔽时打印,避免刷屏
			match event.keycode:
				KEY_E:
					print("[DEBUG] 对话框中屏蔽了E键输入")
				KEY_SPACE:
					print("[DEBUG] 对话框中屏蔽了空格键输入")
				KEY_W:
					print("[DEBUG] 对话框中屏蔽了W键输入")
				KEY_A:
					print("[DEBUG] 对话框中屏蔽了A键输入")
				KEY_S:
					print("[DEBUG] 对话框中屏蔽了S键输入")
				KEY_D:
					print("[DEBUG] 对话框中屏蔽了D键输入")

func start_dialogue(npc_name: String):
	"""开始与NPC对话"""
	current_npc_name = npc_name

	# 通知NPC进入交互状态 (停止移动) 
	var npc = get_npc_by_name(npc_name)
	if npc and npc.has_method("set_interacting"):
		npc.set_interacting(true)

	# 设置NPC信息
	npc_name_label.text = npc_name
	npc_title_label.text = Config.NPC_TITLES.get(npc_name, "")

	# 清空对话内容
	dialogue_text.clear()
	dialogue_text.append_text("[color=gray]与 " + npc_name + " 的对话开始...[/color]\n")

	# 清空输入框
	print("[DEBUG] start_dialogue: 清空输入框，之前内容: '", player_input.text, "'")
	player_input.text = ""
	print("[DEBUG] start_dialogue: 输入框已清空")

	# 显示对话框
	show_dialogue()

	# 聚焦输入框 (使用延迟确保UI完全显示)
	call_deferred("_focus_input")
	print("[INFO] 开始对话: ", npc_name)

func _focus_input():
	"""延迟聚焦输入框"""
	player_input.grab_focus()
	print("[DEBUG] 延迟焦点设置完成，当前焦点状态: ", player_input.has_focus())

func show_dialogue():
	"""显示对话框"""
	visible = true

	# 通知玩家进入交互状态 (禁用移动)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_interacting"):
		player.set_interacting(true)

func hide_dialogue():
	"""隐藏对话框"""
	visible = false

	# 重置发送状态
	is_sending = false

	# 通知NPC退出交互状态 (恢复移动)
	if current_npc_name != "":
		var npc = get_npc_by_name(current_npc_name)
		if npc and npc.has_method("set_interacting"):
			npc.set_interacting(false)

	current_npc_name = ""

	# 通知玩家退出交互状态 (启用移动)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_interacting"):
		player.set_interacting(false)

func _on_send_button_pressed():
	"""发送按钮点击"""
	send_message()

func _on_text_submitted(_text: String):
	"""输入框回车"""
	print("[DEBUG] LineEdit text_submitted 信号触发，文本: ", _text)
	send_message()

func send_message():
	"""发送消息"""
	# 防止重复发送
	if is_sending:
		print("[DEBUG] 正在发送中，忽略重复调用")
		return

	var message = player_input.text.strip_edges()

	print("[DEBUG] send_message 被调用，输入框文本: '", player_input.text, "' 处理后: '", message, "'")

	if message.is_empty():
		print("[DEBUG] 消息为空，返回")
		return

	if current_npc_name.is_empty():
		print("[ERROR] 没有选择NPC")
		return

	# 设置发送标志
	is_sending = true
	print("[DEBUG] 开始发送消息: ", message, " 给 NPC: ", current_npc_name)

	# 显示玩家消息
	dialogue_text.append_text("\n[color=cyan]玩家:[/color] " + message + "\n")

	# 清空输入框
	print("[DEBUG] send_message: 清空输入框，之前内容: '", player_input.text, "'")
	player_input.text = ""
	print("[DEBUG] send_message: 输入框已清空")

	# 显示等待提示
	dialogue_text.append_text("[color=gray]等待回复...[/color]\n")

	# 发送API请求
	if api_client:
		api_client.send_chat(current_npc_name, message)
	else:
		print("[ERROR] API客户端未找到")
		is_sending = false  # 重置标志

func _on_chat_response_received(npc_name: String, message: String):
	"""收到NPC回复"""
	# 重置发送标志
	is_sending = false

	if npc_name != current_npc_name:
		return

	print("[DEBUG] 收到NPC回复: ", npc_name, " -> ", message)

	# 移除"等待回复..."
	var text = dialogue_text.get_parsed_text()
	if text.ends_with("等待回复...\n"):
		# 清除最后一行
		dialogue_text.clear()
		var lines = text.split("\n")
		for i in range(lines.size() - 2):
			dialogue_text.append_text(lines[i] + "\n")

	# 显示NPC回复
	dialogue_text.append_text("[color=yellow]" + npc_name + ":[/color] " + message + "\n")

	# 滚动到底部
	dialogue_text.scroll_to_line(dialogue_text.get_line_count() - 1)

func _on_chat_error(error_message: String):
	"""对话错误"""
	# 重置发送标志
	is_sending = false
	print("[DEBUG] 对话错误: ", error_message)
	dialogue_text.append_text("[color=red]错误: " + error_message + "[/color]\n")

func _on_close_button_pressed():
	"""关闭按钮点击"""
	hide_dialogue()

func _on_text_changed(new_text: String):
	"""输入框文本变化时调用"""
	print("[DEBUG] 输入框文本变化为: '", new_text, "'")

# ⭐ 根据名字获取NPC节点
func get_npc_by_name(npc_name: String) -> Node:
	"""根据名字获取NPC节点"""
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if npc.npc_name == npc_name:
			return npc
	return null
