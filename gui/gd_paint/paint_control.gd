extends Control

'''
DOSTUFF
[X] continuous path brushes:
	[X] use events instead of polling input
	[X] set Input.use_accumulated_input for maximum eventage
[X] one 'brush' per element
[X] top/last brush is updated until input ends
[X] live preview box & circle shapes (top brush is updated as it gets dragged)
[X] get undo working again, should be 1:1 'brush' per undo now
[ ] add use_accumulated_input toggle control? (demo what that does on/off)
[ ] path brush as proper mode:
	[ ] +gui
[X] dabby round brush
[ ] dabby rectangles brush
[ ] working eraser
'''

# Enums for the various modes and brush shapes that can be applied.
enum BrushModes {
	PENCIL,
	ERASER,
	CIRCLE_SHAPE,
	RECTANGLE_SHAPE,
}

enum BrushShapes {
	RECTANGLE,
	CIRCLE,
}

# A list to hold all of the dictionaries that make up each brush.
var brush_data_list = []
var brush_started: bool = false

# The current brush settings: The mode, size, color, and shape we have currently selected.
var brush_mode = BrushModes.PENCIL
var brush_size = 32
var brush_color = Color.BLACK
var brush_shape = BrushShapes.CIRCLE;

# The color of the background. We need this for the eraser (see the how we handle the eraser
# in the _draw function for more details).
var bg_color = Color.WHITE

@onready var drawing_area = $"../DrawingAreaBG"


func _ready() -> void:
	Input.use_accumulated_input = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				brush_start(event.position)
			else:
				brush_continue(event.position)
				brush_end()

	if event is InputEventMouseMotion && brush_started:
		brush_continue(event.position)


func brush_start(mouse_pos: Vector2) -> void:
	# Make new brush dictionary that will hold all of the data we need for the brush.
	var new_brush = {}

	# Populate the dictionary with values based on the global brush variables.
	# We will override these as needed if the brush is a rectange or circle.
	new_brush.brush_type = brush_mode
	new_brush.brush_pos_start = mouse_pos
	new_brush.brush_pos = mouse_pos
	new_brush.brush_shape = brush_shape
	new_brush.brush_size = brush_size
	new_brush.brush_color = brush_color

	if brush_mode == BrushModes.PENCIL or brush_mode == BrushModes.ERASER:
		var brush_path := Curve2D.new()
		brush_path.bake_interval = brush_size / 2.0
		new_brush.brush_path = brush_path

	brush_data_list.push_back(new_brush)
	brush_started = true


func brush_continue(mouse_pos: Vector2) -> void:
	if brush_started:
		var brush = brush_data_list.back()
		if brush.brush_type != brush_mode:
			brush_end()
		else:
			if brush_mode == BrushModes.PENCIL or brush_mode == BrushModes.ERASER:
				if mouse_pos.distance_squared_to(brush.brush_pos) > pow(brush.brush_size / 2.0, 2.0):
					brush.brush_path.add_point(mouse_pos)
					brush.brush_pos = mouse_pos
			else:
				brush.brush_pos = mouse_pos
			queue_redraw()


func brush_end() -> void:
	if brush_started:
		brush_started = false
		queue_redraw()


#func check_if_mouse_is_inside_canvas():
#	# Make sure we have a mouse click starting position.
#	if mouse_click_start_pos != null:
#		# Make sure the mouse click starting position is inside the canvas.
#		# This is so if we start out click outside the canvas (say chosing a color from the color picker)
#		# and then move our mouse back into the canvas, it won't start painting.
#		if Rect2(drawing_area.position, drawing_area.size).has_point(mouse_click_start_pos):
#			# Make sure the current mouse position is inside the canvas.
#			if is_mouse_in_drawing_area:
#				return true
#	return false


func undo_stroke():
	if brush_data_list.is_empty():
		return

	brush_data_list.pop_back()
	queue_redraw()


func _draw():
	# Go through all of the brushes in brush_data_list.
	for brush in brush_data_list:
		match brush.brush_type:
			BrushModes.PENCIL:
				### @@@ NOTE @@@ Not actually a rectangle/circle shaped brush currently!
				### Just (ab)using the existing controls for experimentation...
				if brush.brush_path.get_baked_length() > 1.0:
					if brush.brush_shape == BrushShapes.RECTANGLE:
						## SHARP PATH BRUSH
						draw_polyline(brush.brush_path.get_baked_points(), brush.brush_color, brush.brush_size)
					elif brush.brush_shape == BrushShapes.CIRCLE:
						## BLOBBY CIRCLE BRUSH
						for point in brush.brush_path.get_baked_points():
							var dab_size := float(hash(point) % 0xffff) / float(0xffff)
							draw_circle(point, (brush.brush_size + brush.brush_size * dab_size) / 2.0, brush.brush_color)
#				# If the brush shape is a rectangle, then we need to make a Rect2 so we can use draw_rect.
#				# Draw_rect draws a rectagle at the top left corner, using the scale for the size.
#				# So we offset the position by half of the brush size so the rectangle's center is at mouse position.
#				if brush.brush_shape == BrushShapes.RECTANGLE:
#					var rect = Rect2(brush.brush_pos - Vector2(brush.brush_size / 2, brush.brush_size / 2), Vector2(brush.brush_size, brush.brush_size))
#					draw_rect(rect, brush.brush_color)
#				# If the brush shape is a circle, then we draw a circle at the mouse position,
#				# making the radius half of brush size (so the circle is brush size pixels in diameter).
#				elif brush.brush_shape == BrushShapes.CIRCLE:
#					draw_circle(brush.brush_pos, brush.brush_size / 2, brush.brush_color)
			BrushModes.ERASER:
				# NOTE: this is a really cheap way of erasing that isn't really erasing!
				# However, this gives similar results in a fairy simple way!

				# Erasing works exactly the same was as pencil does for both the rectangle shape and the circle shape,
				# but instead of using brush.brush_color, we instead use bg_color instead.
				if brush.brush_shape == BrushShapes.RECTANGLE:
					var rect = Rect2(brush.brush_pos - Vector2(brush.brush_size / 2, brush.brush_size / 2), Vector2(brush.brush_size, brush.brush_size))
					draw_rect(rect, bg_color)
				elif brush.brush_shape == BrushShapes.CIRCLE:
					draw_circle(brush.brush_pos, brush.brush_size / 2, bg_color)
			BrushModes.RECTANGLE_SHAPE:
				# We make a Rect2 with the postion at the top left. To get the size we take the bottom right position
				# and subtract the top left corner's position.
				var rect = Rect2(brush.brush_pos_start, brush.brush_pos - brush.brush_pos_start)
				draw_rect(rect, brush.brush_color)
			BrushModes.CIRCLE_SHAPE:
				# If the brush isa circle shape, then we need to calculate the radius of the circle.
				# Get the center point inbetween the mouse position and the position of the mouse when we clicked.
#				var center_pos = Vector2((mouse_pos.x + mouse_click_start_pos.x) / 2, (mouse_pos.y + mouse_click_start_pos.y) / 2)
				var center_pos = (brush.brush_pos_start + brush.brush_pos) / 2.0
				# Assign the brush position to the center point, and calculate the radius of the circle using the distance from
				# the center to the top/bottom positon of the mouse.
				var radius = center_pos.distance_to(Vector2(center_pos.x, brush.brush_pos.y))

				# We simply draw a circle using stored in brush.
				draw_circle(center_pos, radius, brush.brush_color)


func save_picture(path):
	# Wait until the frame has finished before getting the texture.
	await RenderingServer.frame_post_draw

	# Get the viewport image.
	var img = get_viewport().get_texture().get_image()
	# Crop the image so we only have canvas area.
	var cropped_image = img.get_region(Rect2(drawing_area.position, drawing_area.size))

	# Save the image with the passed in path we got from the save dialog.
	cropped_image.save_png(path)
