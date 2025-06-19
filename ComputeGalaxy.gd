extends TextureRect

# PARAMS
var img_size :int= 2048 # 1024 # 2048 # 512 # BIG PERFORMANCE CONCERN - also need to adjust %ComputeGalaxy scale and position to match
var bigG :float= .00067
var dt :float= 0.01
var point_count:int= 100000 # 100000
var mass_center :float= 500000.0
var starting_mass_point_scale :float= 1.0
var starting_velocity_magnitude_scale :float= 1.0 * 0.8 #1.05# 1.01 # adjust as desired - even try negative :)
var starting_radius :int= 1900 # 6900 # 250 # Radius of the galactic circle
var starting_arm_count :int= 19 # 12 # Number of spiral arms
var starting_arm_offset :float= 1.00 # .75 # Random offset to spread points around each arm
var shader_local_size = 512
 
# LOCAL STORAGE
var last_pos_array : PackedByteArray
var last_vel_array : PackedByteArray
var last_mass_array : PackedByteArray

# PRIMARY RENDERING VARS
var rd := RenderingServer.create_local_rendering_device()
var shader :RID
var pipeline :RID
var uniform_set :RID
var uniform1 :RDUniform
var uniform2 :RDUniform
var uniform3 :RDUniform
var uniform4 :RDUniform
var uniform5 :RDUniform
var uniform6 :RDUniform

# DATA BUFFERS
var buffer1 :RID
var buffer2 :RID
var buffer3 :RID
var buffer4 :RID
var buffer5 :RID
var buffer6 :RID

# IMAGES
var output_tex_uniform :RDUniform
var output_tex := RID() # main field texture
var fmt := RDTextureFormat.new() # shared format
var view := RDTextureView.new() # shared view

# TIME FRAME COUNTERS AND PERFORM LOGS
var time_count :float = 0.0
var frame_count :int = 0

# POINT PRUNING SETTINGS
var skipCount :bool = false # stop count/rebuild process
var min_points :int = 30000 # min points for prune # 25000 # 1000
var min_zeros :int = 10000 # min zeros before prune
var prune_percent_threshold :float = 0.2 # min percent before prune

# DELTA SPEED SCALING WITH SLIDER
var min_speed :float= 1.0
var max_speed :float= 20.0 # max val from slider == 100 percent of max_output
var min_output :float= .5
var max_output :float= 10.0

func _ready():
	randomize()
	
	# set speed
	%HSliderTimeScale.value = 2  # hardcode start max: 20==max starting speed tick in slider
	dt = scale_map_speed(%HSliderTimeScale.value)
	
	# perflog init
	%PerfGraph.create_entry(0)
	%PerfGraph.performance_log[0]={"frame_count":0,"time_count":0,"point_count":point_count}
	
	# generate reusable output texture format
	fmt = RDTextureFormat.new()
	fmt.width = img_size
	fmt.height = img_size
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT \
					| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
					| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT \
					| RenderingDevice.TEXTURE_USAGE_CPU_READ_BIT
	view = RDTextureView.new()

	# build starting point configurations
	var starting_data :Dictionary= build_starting_points_custom()
	#var starting_data :Dictionary= build_starting_points_basic()
	rebuild_buffers(starting_data['mass_in'], starting_data['positions_in'], starting_data['velocity_in'])

func scale_map_speed(speed: int) -> float:
	if speed == -3:
		return -1.0  # Negative speed case
	elif speed == -2:
		return -0.5  # Negative speed case
	elif speed == -1:
		return min_output*-1  # Negative speed case
	elif speed == 0:
		return 0.0  # Zero speed case
	else:
		return lerp(min_output, max_output, (speed - min_speed) / (max_speed - min_speed))

func build_starting_points_custom():
	var positions_in := PackedVector2Array()
	var velocity_in := PackedVector2Array()
	var mass_in := PackedFloat32Array()
	var center := Vector2(img_size/2, img_size/2) # Center of the circle is center of image
	var n:int
	var distance_to_center
	var velocity_magnitude
	var radial_direction
	var tangential_direction
	var velocity
	
	# center
	positions_in.append(center)
	velocity_in.append(Vector2.ZERO)
	mass_in.append(mass_center)

	# test obj
	n=1
	positions_in.append(center + Vector2(0,200))
	velocity_in.append(Vector2.ZERO)
	mass_in.append(500.0)

	# test obj 2
	n=2
	positions_in.append(center + Vector2(0,-200))
	velocity_in.append(Vector2.ZERO)
	mass_in.append(500.0)

	# test obj 3
	n=3
	positions_in.append(center + Vector2(0,750))
	mass_in.append(25000.0)
	distance_to_center = positions_in[n].distance_to(center)
	velocity_magnitude = sqrt(bigG * mass_center / distance_to_center)
	velocity_magnitude *= starting_velocity_magnitude_scale
	radial_direction = (positions_in[n] - center).normalized()
	tangential_direction = Vector2(-radial_direction.y, radial_direction.x) # Rotate by 90 degrees
	velocity = tangential_direction * velocity_magnitude
	velocity_in.append(velocity)

	# test obj 4
	n=4
	positions_in.append(center + Vector2(0,-750))
	mass_in.append(25000.0)
	distance_to_center = positions_in[n].distance_to(center)
	velocity_magnitude = sqrt(bigG * mass_center / distance_to_center)
	velocity_magnitude *= starting_velocity_magnitude_scale
	radial_direction = (positions_in[n] - center).normalized()
	tangential_direction = Vector2(-radial_direction.y, radial_direction.x) # Rotate by 90 degrees
	velocity = tangential_direction * velocity_magnitude
	velocity_in.append(velocity)

	# test obj 5
	n=5
	positions_in.append(center + Vector2(500,0))
	mass_in.append(2000.0)
	distance_to_center = positions_in[n].distance_to(center)
	velocity_magnitude = sqrt(bigG * mass_center / distance_to_center)
	velocity_magnitude *= starting_velocity_magnitude_scale
	radial_direction = (positions_in[n] - center).normalized()
	tangential_direction = Vector2(-radial_direction.y, radial_direction.x) # Rotate by 90 degrees
	velocity = tangential_direction * velocity_magnitude
	velocity_in.append(velocity)

	# test obj 6
	n=6
	positions_in.append(center + Vector2(-500,0))
	mass_in.append(2000.0)
	distance_to_center = positions_in[n].distance_to(center)
	velocity_magnitude = sqrt(bigG * mass_center / distance_to_center)
	velocity_magnitude *= starting_velocity_magnitude_scale
	radial_direction = (positions_in[n] - center).normalized()
	tangential_direction = Vector2(-radial_direction.y, radial_direction.x) # Rotate by 90 degrees
	velocity = tangential_direction * velocity_magnitude
	velocity_in.append(velocity)

	# add more
	#var starting_data :Dictionary= build_starting_points_basic(false)
	var starting_data :Dictionary= build_starting_points_spiral(false)
	positions_in.append_array(starting_data["positions_in"])
	velocity_in.append_array(starting_data["velocity_in"])
	mass_in.append_array(starting_data["mass_in"])
		
	point_count = mass_in.size()
	return {"positions_in": positions_in, "velocity_in": velocity_in, "mass_in": mass_in}

func build_starting_points_basic(includeCenter=true):
	var positions_in := PackedVector2Array()
	var velocity_in := PackedVector2Array()
	var mass_in := PackedFloat32Array()
	var center := Vector2(img_size/2, img_size/2) # Center of the circle is center of image
	for i in range(point_count):
		var point := Vector2.ZERO
		var mass := randf() * starting_mass_point_scale
		
		if (i == 0 && includeCenter): # first object is the center of the sim
			point = center
			mass = mass_center
		else:
			# Assign the point to a spiral arm based on its index
			var arm_index :int= i % starting_arm_count
			var angle_offset :float= randf() * starting_arm_offset# Randomly spread points along each arm
			
			# Calculate the angle along the spiral arm
			var angle :float= (float(arm_index) / starting_arm_count) * TAU + angle_offset 
			
			# Random distance from center, scaled to form spirals
			var r := sqrt(randf()) * starting_radius
			
			# Convert polar to Cartesian and shift to center
			point = Vector2(r * cos(angle), r * sin(angle)) + center
			
		positions_in.append(point)
		mass_in.append(mass)
		
		# Calculate orbital velocity for circular-ish orbit
		var distance_to_center := point.distance_to(center)
		if distance_to_center > 0: # Avoid division by zero
			var velocity_magnitude := sqrt(bigG * mass_center / distance_to_center)
			
			# HACK: manual adjust because the center star does not represent the entire mass  of the galaxy - we could sum it up to get close mass and better veloc to match
			velocity_magnitude *= starting_velocity_magnitude_scale
			
			# Velocity direction is perpendicular to the radial direction (tangential to the circle)
			var radial_direction := (point - center).normalized()
			var tangential_direction := Vector2(-radial_direction.y, radial_direction.x) # Rotate by 90 degrees
			
			# Final velocity vector
			var velocity := tangential_direction * velocity_magnitude
			velocity_in.append(velocity)
		else:
			velocity_in.append(Vector2.ZERO)
			
	return {"positions_in": positions_in, "velocity_in": velocity_in, "mass_in": mass_in}

func build_starting_points_spiral(includeCenter=true):
	var positions_in := PackedVector2Array()
	var velocity_in := PackedVector2Array()
	var mass_in := PackedFloat32Array()
	var center := Vector2(img_size/2, img_size/2) # Center of the circle is center of image
	var points_per_arm := point_count / starting_arm_count
	
	for i in range(point_count):
		var point := Vector2.ZERO
		var mass := randf() * starting_mass_point_scale
		
		if (i == 0 and includeCenter): # First object is the center of the sim
			point = center
			mass = mass_center
		else:
			# Assign the point to a spiral arm based on its index
			var arm_index : int = i % starting_arm_count
			var point_in_arm : int = i / starting_arm_count
			
			# Calculate the angle along the spiral arm
			var angle_offset : float = point_in_arm + randf() * starting_arm_offset # Spread points along each arm
			var angle : float = (float(arm_index) / starting_arm_count) * TAU + angle_offset
			
			# Distance from center increases with point_in_arm to form a spiral
			var r := sqrt(float(point_in_arm) / float(points_per_arm)) * starting_radius
			
			# Convert polar to Cartesian and shift to center
			point = Vector2(r * cos(angle), r * sin(angle)) + center
		
		positions_in.append(point)
		mass_in.append(mass)
		
		# Calculate orbital velocity for circular-ish orbit
		var distance_to_center := point.distance_to(center)
		if distance_to_center > 0: # Avoid division by zero
			var velocity_magnitude := sqrt(bigG * mass_center / distance_to_center)
			
			# HACK: scale adjust because the center star does not represent the entire mass of the galaxy - we could sum it up to get close mass and better veloc to match
			velocity_magnitude *= starting_velocity_magnitude_scale
			
			# Velocity direction is perpendicular to the radial direction (tangential to the circle)
			var radial_direction := (point - center).normalized()
			var tangential_direction := Vector2(-radial_direction.y, radial_direction.x) # Rotate by 90 degrees
			
			# Final velocity vector
			var velocity := tangential_direction * velocity_magnitude
			velocity_in.append(velocity)
		else:
			velocity_in.append(Vector2.ZERO)
			
	return {"positions_in": positions_in, "velocity_in": velocity_in, "mass_in": mass_in}
	
func _process(_delta):
	var output_bytes_pos :PackedByteArray
	var output_bytes_vel :PackedByteArray
	var output_bytes_mass :PackedByteArray
	var byte_data : PackedByteArray
	var image :Image
	var compute_list :int
	var params :PackedFloat32Array
	var params_bytes :PackedByteArray
	var global_size = (point_count/shader_local_size)+1
	#print("GLOBAL SIZE ", global_size)
	
	# set speed
	dt = scale_map_speed(%HSliderTimeScale.value)
	if is_zero_approx(dt):
		return

	%PerfGraph.queue_redraw()

	# increment frame counter and total time counter
	frame_count += 1
	time_count += dt

	# perflog
	%PerfGraph.create_entry(frame_count)
	%PerfGraph.set_static_value(frame_count,"frame_count",frame_count)
	%PerfGraph.set_static_value(frame_count,"time_count",time_count)
	%PerfGraph.set_static_value(frame_count,"point_count",point_count)

	###########################################
	# PASS 1 ##################################
	###########################################
	
	# start compute list
	compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	# shader PUSH CONSTANT params
	params = [0, bigG, dt, point_count] # padded to multiple of 4 floats when needed
	params_bytes = PackedInt32Array([]).to_byte_array()
	params_bytes.append_array(params.to_byte_array())
	rd.compute_list_set_push_constant(compute_list,params_bytes,params_bytes.size())

	# finish list and proceed to compute PASS 1
	%PerfGraph.start_debug_timer(frame_count, "pass1")
	rd.compute_list_dispatch(compute_list, global_size, 1, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()   # BIG PERFORMANCE CONCERN
	%PerfGraph.end_debug_timer(frame_count, "pass1")

	###########################################
	# PASS 2 ##################################
	###########################################
	
	# start compute list
	compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	# shader PUSH CONSTANT params
	params = [1, bigG, dt, point_count] # padded to multiple of 4 floats when needed
	params_bytes = PackedInt32Array([]).to_byte_array()
	params_bytes.append_array(params.to_byte_array())
	rd.compute_list_set_push_constant(compute_list,params_bytes,params_bytes.size())
	
	# finish list and proceed to compute PASS 2
	%PerfGraph.start_debug_timer(frame_count, "pass2")
	rd.compute_list_dispatch(compute_list, global_size, 1, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()   # BIG PERFORMANCE CONCERN
	%PerfGraph.end_debug_timer(frame_count, "pass2")

	############################################
	## RESOLVE RESULTS #########################
	############################################
	
	# GRAB DETAILS FROM BUFFERS
	output_bytes_pos = rd.buffer_get_data(buffer4)
	output_bytes_vel = rd.buffer_get_data(buffer5)
	output_bytes_mass = rd.buffer_get_data(buffer6)

	# STORE LATEST ARRAYS
	%PerfGraph.start_debug_timer(frame_count, "convArrs")
	last_pos_array = output_bytes_pos
	last_vel_array = output_bytes_vel
	last_mass_array = output_bytes_mass
	%PerfGraph.end_debug_timer(frame_count, "convArrs")
	
	# check zero masses and maybe rebuild buffers
	if(check_zero_masses()):
		return
	
	# SWAP GRID TO NEXT GRID - CPU -> GPU buffer updates
	rd.buffer_update(buffer1, 0, output_bytes_pos.size(), output_bytes_pos)
	rd.buffer_update(buffer2, 0, output_bytes_vel.size(), output_bytes_vel)
	rd.buffer_update(buffer3, 0, output_bytes_mass.size(), output_bytes_mass)
		
	# and set main image
	%PerfGraph.start_debug_timer(frame_count, "getData")
	if (%ComputeGalaxy.visible||%SubViewportContainerZoom.visible):
		byte_data = rd.texture_get_data(output_tex, 0) # BIG PERFORMANCE CONCERN
	%PerfGraph.end_debug_timer(frame_count, "getData")
		
	%PerfGraph.start_debug_timer(frame_count, "crtImg")
	if (%ComputeGalaxy.visible||%SubViewportContainerZoom.visible):
		image = Image.create_from_data(img_size, img_size, false, Image.FORMAT_RGBAF, byte_data)
	%PerfGraph.end_debug_timer(frame_count, "crtImg")
	
	%PerfGraph.start_debug_timer(frame_count, "updTex")
	if (%ComputeGalaxy.visible||%SubViewportContainerZoom.visible):
		texture.update(image)
	%PerfGraph.end_debug_timer(frame_count, "updTex")

func check_zero_masses() -> bool:
	%PerfGraph.start_debug_timer(frame_count, "zeroCc")
	if(!skipCount):
  		# BIG PERFORMANCE CONCERN	- any way to use reduction on GPU?
		var mass_array :PackedFloat32Array = last_mass_array.to_float32_array()
		var zero_masses := mass_array.count(0.0)
		
		if(point_count-zero_masses > min_points && zero_masses> min_zeros && zero_masses>int(point_count * prune_percent_threshold)): # prune size with min and max
			remove_zero_masses(mass_array)
			return true

		if(point_count < min_points):
			skipCount=true
	%PerfGraph.end_debug_timer(frame_count, "zeroCc")
	return false
	
func remove_zero_masses(mass_array:PackedFloat32Array):
	var result_mass := PackedFloat32Array()
	var result_pos := PackedVector2Array()
	var result_veloc := PackedVector2Array()
	
	%PerfGraph.start_debug_timer(frame_count, "zeroCa")
	var pos_array = Utility.float_byte_array_to_Vector2Array(last_pos_array)
	var vel_array = Utility.float_byte_array_to_Vector2Array(last_vel_array)
	for i in range(0,point_count):
		var mass_check = mass_array[i]
		if not is_zero_approx(mass_check):
			result_mass.append(mass_check)
			result_pos.append(pos_array[i])
			result_veloc.append(vel_array[i])
	%PerfGraph.end_debug_timer(frame_count, "zeroCa")
	
	%PerfGraph.start_debug_timer(frame_count, "zeroCb")
	rebuild_buffers(result_mass,result_pos,result_veloc,false)
	%PerfGraph.end_debug_timer(frame_count, "zeroCb")
	
func rebuild_buffers(result_mass: PackedFloat32Array, result_pos: PackedVector2Array, result_veloc: PackedVector2Array, reset_image=true):
	# Update the `point_count` with the new number of points
	point_count = result_mass.size()
	#print(point_count)
	
	# load and begin compiling compute shader
	var shader_file :RDShaderFile= load("res://compute_galaxy.glsl")
	var shader_spirv :RDShaderSPIRV= shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)
	
	# Create new byte arrays for the filtered data
	var data1: PackedByteArray = PackedByteArray()
	data1.append_array(result_pos.to_byte_array()) # position in

	var data2: PackedByteArray = PackedByteArray()
	data2.append_array(result_veloc.to_byte_array()) # velocity in

	var data3: PackedByteArray = PackedByteArray()
	data3.append_array(result_mass.to_byte_array()) # masses in

	var data4 :PackedByteArray= PackedByteArray()
	data4 = data1.duplicate() # position out

	var data5 :PackedByteArray= PackedByteArray()
	data5 = data2.duplicate() # velocity out

	var data6 :PackedByteArray= PackedByteArray()
	data6 = data3.duplicate() # masses out

	# Update the storage buffers with the new data
	buffer1 = rd.storage_buffer_create(data1.size(), data1)
	buffer2 = rd.storage_buffer_create(data2.size(), data2)
	buffer3 = rd.storage_buffer_create(data3.size(), data3)
	buffer4 = rd.storage_buffer_create(data4.size(), data4)
	buffer5 = rd.storage_buffer_create(data5.size(), data5)
	buffer6 = rd.storage_buffer_create(data6.size(), data6)

	# reset image
	if reset_image:
		var output_image := Image.create(img_size, img_size, false, Image.FORMAT_RGBAF)
		var image_texture := ImageTexture.create_from_image(output_image)
		texture = image_texture
		output_tex = rd.texture_create(fmt, view, [output_image.get_data()])

	# Uniforms need to be updated with the new buffers
	uniform1 = RDUniform.new()
	uniform1.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform1.binding = 0 
	uniform1.add_id(buffer1)

	uniform2 = RDUniform.new()
	uniform2.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform2.binding = 1 
	uniform2.add_id(buffer2)

	uniform3 = RDUniform.new()
	uniform3.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform3.binding = 2 
	uniform3.add_id(buffer3)

	uniform4 = RDUniform.new()
	uniform4.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform4.binding = 3 
	uniform4.add_id(buffer4)
	
	uniform5 = RDUniform.new()
	uniform5.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform5.binding = 4 
	uniform5.add_id(buffer5)
	
	uniform6 = RDUniform.new()
	uniform6.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform6.binding = 5 
	uniform6.add_id(buffer6)
	
	output_tex_uniform = RDUniform.new()
	output_tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_tex_uniform.binding = 6
	output_tex_uniform.add_id(output_tex)

	# Recreate the uniform set
	uniform_set = rd.uniform_set_create([uniform1, uniform2, uniform3, uniform4, uniform5, uniform6, output_tex_uniform], shader, 0)
