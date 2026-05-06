#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D screen_buffer;

layout(rgba16f, set = 0, binding = 1) uniform image2D accumulation_buffer;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	int line_width;
	int v_offset;
};

// The code we want to execute in each invocation
void main() {
	
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(raster_size);
	vec2 uvn = uv/size;

	// Prevent reading/writing out of bounds.
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}
	vec4 frame_color = imageLoad(screen_buffer, uv);

	vec4 line_color = imageLoad(accumulation_buffer, uv);

	float delta = float(int((uv.y + v_offset) / line_width) % 2);

	vec4 final_color = mix(frame_color, line_color, delta);

	imageStore(accumulation_buffer, uv, frame_color);

	imageStore(screen_buffer, uv, final_color);
}
