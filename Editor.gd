extends Control

onready var file_tree = $PanelContainer/VBoxContainer/PanelContainer/HBoxContainer/Tree
onready var action_popup = $PopupMenu
onready var content_editor = $PanelContainer/VBoxContainer/PanelContainer/HBoxContainer/Editor
var working_directory = null
var folder_structure = {}
var timelines = {}
var current_selected_item = null

func _ready():
	$PanelContainer/VBoxContainer/HBoxContainer2/Button.connect("pressed", self, "_on_load_dialogic_pressed")
	$PanelContainer/VBoxContainer/HBoxContainer2/SyncButton.connect("pressed", self, "_sync_tree_with_data")
	$FileDialog.connect("dir_selected", self, "_parse_folder")
	file_tree.set_column_min_width(0, 16)
	file_tree.connect("item_rmb_selected", self, "_on_item_rmb")
	file_tree.connect("item_edited", self, "_on_item_edited")
	file_tree.connect("item_selected", self, "_on_item_selected")
	action_popup.connect("id_pressed", self, "_on_action_menu_pressed")
	content_editor.connect("text_changed", self, "_on_contents_edited")
	
	var config = ConfigFile.new()
	config.load("user://config.cfg")
	var default_dir = config.get_value("Global", "default_directory", "/")
	$FileDialog.current_dir = default_dir
	
	pass
	
	
func _on_load_dialogic_pressed():
	$FileDialog.show()
	
	
func _on_action_menu_pressed(id):
	if (id == 0): # New Timeline
		_add_new_folder()
	if (id == 1): # New Timeline
		_add_new_timeline()
	if (id == 2): # New Timeline
		_delete_item()
	
	
func _on_item_rmb(position):
	current_selected_item = file_tree.get_selected()
	action_popup.rect_position = position
	action_popup.show()
	
	pass
	
	
func _on_item_selected():
	var selected_item = file_tree.get_selected()
	if (selected_item.get_metadata(0)["type"] == "timeline"):
		var contents = timelines[selected_item.get_metadata(0)["file_name"]]
		content_editor.visible = true
		content_editor.text = JSON.print(contents, "\t")
	else:
		content_editor.visible = false
		content_editor.text = ""
	pass
	
	
func _on_contents_edited():
	var selected_item = file_tree.get_selected()
	if (selected_item != null and selected_item.get_metadata(0)["type"] == "timeline"):
		var file_name = selected_item.get_metadata(0)["file_name"]
		var text = $PanelContainer/VBoxContainer/PanelContainer/HBoxContainer/Editor.text
		var result = JSON.parse(text)
		if (result.error == OK):
			var new_data = result.result
			new_data["metadata"] = timelines[file_name]["metadata"]
			timelines[file_name] = new_data
		
	pass
	
	
func _on_item_edited():
	var edited = file_tree.get_edited()
	var meta = edited.get_metadata(0)
	if (meta["type"] == "timeline"):
		var file_name = meta["file_name"]
		var timeline_data = timelines[file_name]
		var timeline_metadata = timeline_data["metadata"]
		timeline_metadata["name"] = edited.get_text(0)
		
	if (file_tree.get_edited() == file_tree.get_selected()):
		_on_item_selected()
	
	
func _add_new_folder():
	var new_name = _get_unique_name("folder")
	
	var root = current_selected_item
	if (current_selected_item.get_metadata(0)["type"] == "timeline"):
		root = current_selected_item.get_parent()
	var new_item = _create_folder_item(root, new_name)
	file_tree.scroll_to_item(new_item)
	pass
	
	
func _add_new_timeline():
	var new_name = _get_unique_name("timeline")
	var new_timeline = {}
	new_timeline["events"] = []
	new_timeline["metadata"] = {
		"dialogic-version": "1.4.5",
		"file": new_name + ".json",
		"name": new_name
	}
	timelines[new_name + ".json"] = new_timeline
	
	var root = current_selected_item
	if (current_selected_item.get_metadata(0)["type"] == "timeline"):
		root = current_selected_item.get_parent()
	var new_item = _create_timeline_item(root, new_name + ".json")
	file_tree.scroll_to_item(new_item)
	new_item.get_parent().collapsed = false
	
	pass
	
	
func _delete_item():
	if (current_selected_item.get_metadata(0)["type"] == "timeline"):
		timelines.erase(current_selected_item.get_metadata(0)["file_name"])
	elif (current_selected_item.get_metadata(0)["type"] == "folder"):
		_recursive_delete_folder(current_selected_item)
	
	current_selected_item.free()
	
	pass
	
	
func _recursive_delete_folder(tree_item: TreeItem):
	var child = tree_item.get_children()
	while child != null:
		if (child.get_metadata(0)["type"] == "timeline"):
			timelines.erase(child.get_metadata(0)["file_name"])
		elif(child.get_metadata(0)["type"] == "folder"):
			_recursive_delete_folder(child)
		child = child.get_next()
	
	pass
	
	
func _parse_folder(dir_path):
	var dir = Directory.new()
	
	# Reset everything for a new directory.
	working_directory = null
	timelines.clear()
	file_tree.clear()
	folder_structure.clear()
	
	if dir.open(dir_path) == OK:
		var config = ConfigFile.new()
		config.set_value("Global", "default_directory", dir_path)
		config.save("user://config.cfg")
		
		content_editor.visible = false
		
		working_directory = dir_path
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() == false:
				if (file_name == "folder_structure.json"):
					var file = File.new()
					file.open(dir_path + "/" + file_name, File.READ)
					var file_contents = file.get_as_text()
					folder_structure = parse_json(file_contents)
					
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	
	_get_timelines()
	_update_tree()
	
	pass
	
	
func _get_name_for_timeline(file_path):
	var timeline_data = timelines.get(file_path, {})
	var meta_data = timeline_data.get("metadata", {})
	var name = meta_data.get("name", file_path)
	
	return name
	
	
func _get_timelines():
	if (working_directory != null):
		var dir = Directory.new()
		if dir.open(working_directory + "/timelines") == OK:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if dir.current_is_dir() == false:
					if (file_name.ends_with(".json")):
						var file = File.new()
						file.open(working_directory + "/timelines/" + file_name, File.READ)
						var file_contents = file.get_as_text()
						timelines[file_name] = parse_json(file_contents)
						
				file_name = dir.get_next()
	
	
func _update_tree():
	if (working_directory != null):
		var folders = folder_structure.get("folders", {})
		var timelines = folders.get("Timelines", {})
		
		var root = file_tree.create_item()
		root.set_icon(0, preload("res://FolderIcon.png"))
		root.set_text(0, "timelines")
		var metadata = {
			"type": "root"
		}
		root.set_metadata(0, metadata)
		_update_tree_recursive(root, timelines)
	
	
func _update_tree_recursive(root, value):
	var timeline_files = value.get("files", [])
	var timeline_folders = value.get("folders", {})
	
	for file in timeline_files:
		var file_item = _create_timeline_item(root, file)
		
	for folder in timeline_folders:
		var folder_item = _create_folder_item(root, folder)
		_update_tree_recursive(folder_item, timeline_folders[folder])
	
	pass
	
	
func _create_timeline_item(root, file):
	var file_item = file_tree.create_item(root)
	file_item.set_icon(0, preload("res://TimelineIcon.png"))
	file_item.set_text(0, _get_name_for_timeline(file))
	file_item.set_editable(0, true)
	var metadata = {
		"type": "timeline",
		"file_name": file
	}
	file_item.set_metadata(0, metadata)
	return file_item
	
	
func _create_folder_item(root, folder):
	var folder_item = file_tree.create_item(root)
	folder_item.set_icon(0, preload("res://FolderIcon.png"))
	folder_item.set_text(0, folder)
	folder_item.set_editable(0, true)
	var metadata = {
		"type": "folder"
	}
	folder_item.set_metadata(0, metadata)
	folder_item.collapsed = true
	return folder_item
	
	
func _get_unique_name(name: String):
	return name + "-" + str(OS.get_unix_time())
	
	
#######################################################
# Syncing data
#######################################################
	
func _sync_tree_with_data():
	_sync_timelines()
	_sync_folder_structure()
	
	pass
	
	
func _sync_timelines():
	if (working_directory == null):
		return
		
	for timeline_file_name in timelines:
		var file = File.new()
		file.open(working_directory + "/timelines/" + timeline_file_name, File.WRITE)
		file.store_line(JSON.print(timelines[timeline_file_name], "\t"))
		file.close()
	
	# Remove unused timelines
	var tl_dir = Directory.new()
	if tl_dir.open(working_directory + "/timelines") == OK:
		tl_dir.list_dir_begin()
		var file_name = tl_dir.get_next()
		while file_name != "":
			if (tl_dir.current_is_dir() == false):
				if (timelines.has(file_name) == false):
					tl_dir.remove(file_name)
					
			file_name = tl_dir.get_next()
	
	
func _sync_folder_structure():
	var root = file_tree.get_root()
	
	var files = []
	var folders = {}
	
	var structure = _get_folder_recursive(root)
	
	folder_structure["folders"]["Timelines"] = structure
	
	var folder_structure_file = File.new()
	folder_structure_file.open(working_directory + "/folder_structure.json", File.WRITE)
	folder_structure_file.store_line(JSON.print(folder_structure, "\t"))
	folder_structure_file.close()
	
	print(folder_structure)
	
	pass
	
	
func _get_folder_recursive(tree_item: TreeItem):
	var files = []
	var folders = {}
	
	var child = tree_item.get_children()
	if (child != null):
		while child != null:
			var child_meta = child.get_metadata(0)
			if (child_meta["type"] == "timeline"):
				files.append(child_meta["file_name"])
			if (child_meta["type"] == "folder"):
				folders[child.get_text(0)] = _get_folder_recursive(child)
			child = child.get_next()
			
	var structure = {
		"files": files,
		"folders": folders,
		"metadata": {
			"color": null,
			"folded": true
		}
	}
	
	return structure
