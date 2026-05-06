#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D screen_buffer;

layout(rgba16f, set = 0, binding = 1) uniform image2D accumulation_buffer;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float angle;
	float mem_buffer;
	int line_width;
	int v_offset;
};

const float PI = 3.14;

mat2 rotationMatrix(float rot) {
	rot *= PI / 180.0;
	float sine = sin(rot), cosine = cos(rot);
	return mat2( cosine, -sine,
				 sine,    cosine );
}

float sdSegment(vec2 p, vec2 a, vec2 b, float width) {
	vec2 pa = p-a;
	vec2 ba = b-a;
	float h = clamp(dot(pa, ba)/dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - width;
}

float sdRepeat(vec2 p, vec2 a, vec2 b, float width, float s, float rot) {
	vec2 r2 = p;
	r2 *= rotationMatrix(rot);
	r2.y = r2.y - s * round(r2.y/s);
	return sdSegment(r2, a, b, width);
}

// The code we want to execute in each invocation
void main() {
	
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(raster_size);

	// Prevent reading/writing out of bounds.
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}
	vec4 frame_color = imageLoad(screen_buffer, uv);

	vec4 line_color = imageLoad(accumulation_buffer, uv);

	vec2 p = vec2(uv);
	p.y += v_offset;
	vec2 a = vec2(-raster_size.x * 4.0, 0.0);
	vec2 b = vec2(raster_size.x * 4.0, 0.0);
	float sdf = sdRepeat(p, a, b, line_width, line_width*4, angle);

	vec4 final_color = mix(frame_color, line_color, sdf);

	imageStore(accumulation_buffer, uv, frame_color);

	imageStore(screen_buffer, uv, final_color);
}
