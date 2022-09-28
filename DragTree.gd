extends Tree


func get_drag_data(position):
	var preview = Label.new()
	preview.text = get_selected().get_text(0)
	set_drag_preview(preview)
	
	return get_selected()


func can_drop_data(position, data):
	return data is TreeItem
	

func drop_data(position, item):
	var drop_item = get_item_at_position(position)
	
	var new_parent = drop_item
	if (drop_item.get_metadata(0)["type"] == "timeline"):
		new_parent = drop_item.get_parent()
		
	# Check if moving to same folder
	if (new_parent == item.get_parent()):
		return
	
	# Check if folder has an existing timeline with the same name
	var child = new_parent.get_children()
	while child != null:
		if (child.get_text(0) == item.get_text(0)):
			return
		child = child.get_next()
	
	var dupe_item = create_item(new_parent)
	dupe_item.set_text(0, item.get_text(0))
	dupe_item.set_icon(0, item.get_icon(0))
	dupe_item.set_metadata(0, item.get_metadata(0))
	dupe_item.set_editable(0, true)
	
	item.free()
	
	pass
