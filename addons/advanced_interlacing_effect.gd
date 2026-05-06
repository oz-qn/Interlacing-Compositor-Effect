@tool
class_name AdvancedInterlacingEffect extends CompositorEffect

const SHADER_PATH: String = "res://addons/advanced_interlacing_effect.glsl"


## Make Frame Update Frequency update automatically based on the Target Update FPS.
## WARNING: If the framerate of your project is unstable this will make the effect look significantly worse.
@export var adjust_update_frequency_automatically: bool = false
## If Adjust Update Frequency Automatically is true, Frame Update Frequency will be automatically set based on 
## how often you want the interlace buffer to update every second.
@export var target_update_fps: int = 60
## This is how often the past buffer should update. 0 is every frame(1 frame behind), 1 is every other frame and so forth.
## This is useful for making the effect more pronounced at higher refresh rates.
## Values set too high can get a jittery look so be careful using this.
@export var frame_update_frequency: int = 0
@export_range(1, 100, 1.0) var line_width: int = 2
@export_range(0, 100, 1.0) var line_offset: int = 0
@export var scrolling_lines: bool = false
@export var scroll_speed: int = 1
@export var rotating_lines: bool = false
@export_range(-180.0, 180.0, 0.01) var angle: float = 0.0
@export var rotating_speed: float = 30.0

var rd: RenderingDevice
var shader: RID
var pipeline: RID

var stored_size: Vector2i

var _update_timer: int = 0
var buffer_set: bool = false
var accumulated_buffer: RID

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)

# System notifications, we want to react on the notification that
# alerts us we are about to be destroyed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			# Freeing our shader will also free any dependents such as the pipeline!
			rd.free_rid(shader)
			rd.free_rid(linear_sampler)
			rd.free_rid(accumulated_buffer)

var linear_sampler: RID

#region Code in this region runs on the rendering thread.
# Compile our shader at initialization.
func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return
	
	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear_sampler = rd.sampler_create(sampler_state)
	
	# Compile our shader.
	var shader_file := load(SHADER_PATH)
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	
	buffer_set = false
	
	shader = rd.shader_create_from_spirv(shader_spirv)
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)
		

func update_accumulation_buffer(_size: Vector2i) -> void:
	if accumulated_buffer.is_valid():
		rd.free_rid(accumulated_buffer)
	var img := Image.create_empty(_size.x, _size.y, false, Image.FORMAT_RGBAH)
	var tex_format := RDTextureFormat.new()
	tex_format.width = _size.x
	tex_format.height = _size.y
	tex_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	tex_format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	accumulated_buffer = rd.texture_create(tex_format, RDTextureView.new(), [img.get_data()])

# Called by the rendering thread every frame.
func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and pipeline.is_valid():
		# Get our render scene buffers object, this gives us access to our render buffers.
		# Note that implementation differs per renderer hence the need for the cast.
		var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
		if render_scene_buffers:
			var size: Vector2i = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return
			
			if stored_size != size:
				stored_size = size
				update_accumulation_buffer(size)
			
			# We can use a compute shader here.
			@warning_ignore("integer_division")
			var x_groups := (size.x - 1) / 8 + 1
			@warning_ignore("integer_division")
			var y_groups := (size.y - 1) / 8 + 1
			var z_groups := 1
			
			if rotating_lines:
				angle = fmod(angle + deg_to_rad(rotating_speed), 180.0)
			
			
			# Create push constant.
			# Must be aligned to 16 bytes and be in the same order as defined in the shader.
			var push_constant := PackedFloat32Array([
				size.x,
				size.y,
				angle
			]).to_byte_array()
			var pc2: PackedByteArray = PackedInt32Array([
				line_width,
				line_offset,
				_update_timer,
				0,
				0
			]).to_byte_array()
			push_constant.append_array(pc2)
			
			if adjust_update_frequency_automatically: 
				frame_update_frequency = ceili(Engine.get_frames_per_second() / target_update_fps) - 1
			
			if _update_timer <= 0:
				_update_timer = frame_update_frequency + 1
			_update_timer -= 1
			
			if scrolling_lines:
				line_offset = (line_offset + scroll_speed) % (line_width*4)
			
			# Loop through views just in case we're doing stereo rendering. No extra cost if this is mono.
			var view_count: int = render_scene_buffers.get_view_count()
			for view in view_count:
				var uniform_set: RID
				
				# Get the RID for our color image, we will be reading from and writing to it.
				var color_buffer: RID = render_scene_buffers.get_color_layer(view)
				
				# Create a uniform set, this will be cached, the cache will be cleared if our viewports configuration is changed.
				var u_output_buffer := RDUniform.new()
				u_output_buffer.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				u_output_buffer.binding = 0
				u_output_buffer.add_id(color_buffer)
				
				var u_acc_buffer := RDUniform.new()
				u_acc_buffer.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				u_acc_buffer.binding = 1
				u_acc_buffer.add_id(accumulated_buffer)
				
				uniform_set = UniformSetCacheRD.get_cache(shader, 0, [u_output_buffer, u_acc_buffer])
				
				# Run our compute shader.
				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
				rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()
#endregion
