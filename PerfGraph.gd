extends TextureRect

var performance_log :Array= [] # holds up to max_offset_frame entries - then pop from front to discard
var max_offset_frame :int= 475

func start_debug_timer(frame_count, key):
	if(frame_count > max_offset_frame):
		frame_count = max_offset_frame
	
	if !performance_log[frame_count].has(key):
		performance_log[frame_count][key] = {}

	var startDebugTimer = Time.get_ticks_usec()
	performance_log[frame_count][key]['start']=startDebugTimer
	performance_log[frame_count][key]['end']=startDebugTimer
	performance_log[frame_count][key]['time']=0
	
func end_debug_timer(frame_count, key):
	if(frame_count > max_offset_frame):
		frame_count = max_offset_frame
			
	var endDebugTimer = Time.get_ticks_usec()
	performance_log[frame_count][key]['end']=endDebugTimer
	performance_log[frame_count][key]['time']=(endDebugTimer-performance_log[frame_count][key]['start'])/1000000.0

func set_static_value(frame_count, key, val):
	if(frame_count > max_offset_frame):
		frame_count = max_offset_frame
	performance_log[frame_count][key]=val

func create_entry(frame_count):
	#print("CREATE FRAME LOG ", frame_count)
	if frame_count > max_offset_frame:
		performance_log.pop_front()
	performance_log.append({"frame_count":frame_count})

func _draw() -> void:
	if !%SubViewportContainerPerfGraph.visible || is_zero_approx(%ComputeGalaxy.dt) :
		return

	# TODO: need to find better way to shift the existing graph to left without redrawing every column every time - should be able to draw only the last column during each draw
	
	var frame = 0
	for key in performance_log:

		var val = performance_log[frame]["point_count"]
		draw_circle(Vector2((frame * 2), (-val / 120) + 950), 1, Color.GREEN_YELLOW)

		if performance_log[frame].has("pass1"):
			draw_circle(Vector2((frame * 2), (-performance_log[frame]["pass1"]['time'] * 3000) + 925), 1, Color.RED)

		if performance_log[frame].has("pass2"):
			draw_circle(Vector2((frame * 2), (-performance_log[frame]["pass2"]['time'] * 3000) + 926), 1, Color.DARK_RED)

		if performance_log[frame].has("convArrs"):
			draw_circle(Vector2((frame * 2), (-performance_log[frame]["convArrs"]['time'] * 3000) + 927), 1, Color.ORANGE_RED)

		if performance_log[frame].has("zeroCa"):
			draw_circle(Vector2((frame * 2), (-performance_log[frame]["zeroCa"]['time'] * 3000) + 928), 1, Color.YELLOW)

		#if performance_log[frame].has("zeroCb"):
			#draw_circle(Vector2((frame * 2), (-performance_log[frame]["zeroCb"]['time'] * 3000) + 929), 1, Color.ORANGE)

		#if performance_log[frame].has("zeroCc"):
			#draw_circle(Vector2((frame * 2), (-performance_log[frame]["zeroCc"]['time'] * 3000) + 930), 1, Color.WEB_GRAY)

		if performance_log[frame].has("getData"):
			draw_circle(Vector2((frame * 2), (-performance_log[frame]["getData"]['time'] * 3000) + 931), 1, Color.WHITE)
			
		#if performance_log[frame].has("crtImg"):
			#draw_circle(Vector2((frame * 2), (-performance_log[frame]["crtImg"]['time'] * 3000) + 932), 1, Color.GREEN)
			
		if performance_log[frame].has("updTex"):
			draw_circle(Vector2((frame * 2), (-performance_log[frame]["updTex"]['time'] * 3000) + 933), 1, Color.DARK_GREEN)

		frame+=1
