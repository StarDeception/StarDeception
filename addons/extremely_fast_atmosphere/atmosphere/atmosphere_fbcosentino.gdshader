// Created by Fernando Cosentino (github.com/fbcosentino)
// MIT License

shader_type spatial;
render_mode blend_mix, depth_test_disabled, unshaded;

uniform sampler2D DEPTH_TEXTURE: hint_depth_texture, filter_linear_mipmap;

uniform sampler2D height_profile_curve: source_color, filter_linear, repeat_disable;
uniform sampler2D height_profile_main_colors: source_color, filter_linear, repeat_disable;
uniform sampler2D height_profile_back_colors: source_color, filter_linear, repeat_disable;

uniform sampler2D direction_profile_curve: source_color, filter_linear, repeat_disable;
uniform sampler2D direction_profile_main_colors: source_color, filter_linear, repeat_disable;
uniform sampler2D direction_profile_back_colors: source_color, filter_linear, repeat_disable;

uniform sampler2D water_depth_profile_colors: source_color, filter_linear, repeat_disable;

uniform float sea_level = 100.0;
uniform float atmosphere_radius = 120.0;
uniform float atmosphere_density = 0.2;
uniform float water_density_factor = 0.0;


// Returns vec2 with distance where it enters the sphere and distance where it exits
// If ray didn't hit sphere, returns vec2(-1)
vec2 ray_sphere_intersect(vec3 start, vec3 dir, float max_dist, float radius) {
	// calculate the start and end position of the ray, as a distance along the ray
	// we do this with a ray sphere intersect
	float a = dot(dir, dir);
	float b = 2.0 * dot(dir, start);
	float c = dot(start, start) - (radius * radius);
	float d = (b * b) - 4.0 * a * c;

	// stop early if there is no intersect
	if (d < 0.0) return vec2(-1.0);

	// calculate the ray length
	vec2 ray_length = vec2(
		max((-b - sqrt(d)) / (2.0 * a), 0.0),
		min((-b + sqrt(d)) / (2.0 * a), max_dist)
	);

	return ray_length;
}

float get_average_height(vec3 ro, vec3 rd) {
	float t = (dot(-ro, rd));
	if (t < 0.0) {
		return length(ro);
	}
	vec3 P = ro + rd*t;
	return length(P);
}


varying vec3 cam_position;
varying vec3 light_direction;

void vertex() {
	cam_position = MODELVIEW_MATRIX[3].xyz;

	light_direction = -normalize(MODELVIEW_MATRIX[2].xyz);
}

void fragment() {
	float depth = textureLod(DEPTH_TEXTURE, SCREEN_UV, 0.0).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 pixel_position = upos.xyz / upos.w;

	// max_distance is the distance in meters between camera and planet
	float max_distance = length(pixel_position);

	vec3 world_pixel_position = (INV_VIEW_MATRIX * vec4(pixel_position, 1.0)).xyz;

	vec2 atmo_sphere_intersect = ray_sphere_intersect(cam_position, VIEW, max_distance, atmosphere_radius);
	if ((atmo_sphere_intersect.x < 0.0) || (atmo_sphere_intersect.y < 0.0)) {
		discard;
	}
	float ray_length = atmo_sphere_intersect.y - atmo_sphere_intersect.x;

	vec3 global_view = (INV_VIEW_MATRIX * vec4(VIEW, 1.0)).xyz;

	// Point in outer atmosphere where this pixel is
	vec3 atmo_normal = normalize(cam_position + VIEW * max(0.0, min(atmo_sphere_intersect.y, atmo_sphere_intersect.x)));
	float atmo_normal_dot = dot(atmo_normal, light_direction);
	float atmo_normal_side_dot = clamp(dot(VIEW, light_direction), 0.0, 1.0);
	float back_looking_fac = clamp(-atmo_normal_dot * atmo_normal_side_dot * 2.0, 0.0, 1.0);

	// -------------------------------------------------------------------------
	// Height

	float atmo_height = (atmosphere_radius - sea_level);
	float height_avg = get_average_height(cam_position, VIEW);
	float height_above_surface = clamp((height_avg - sea_level) / atmo_height, 0.0, 1.0);
	//float height_fac = exp(-height_above_surface * density_factor) * (1.0 - height_above_surface);
	vec2 height_uv = vec2(height_above_surface, 0.0);
	float height_fac = texture(height_profile_curve, height_uv).r;
	vec4 height_color = mix(
		texture(height_profile_main_colors, height_uv),
		texture(height_profile_back_colors, height_uv),
		back_looking_fac
	);


	// -------------------------------------------------------------------------
	// Light direction

	vec2 direction_uv = vec2(atmo_normal_dot*0.5 + 0.5, 0.0);
	float direction_fac = texture(direction_profile_curve, direction_uv).r;
	vec4 direction_color = mix(
		texture(direction_profile_main_colors, direction_uv),
		texture(direction_profile_back_colors, direction_uv),
		back_looking_fac
	);
	float light_dir_factor = clamp(direction_fac, 0.0, 1.0);


	ALBEDO = height_color.rgb * direction_color.rgb;
	ALPHA = clamp(
		(ray_length / sea_level) * height_fac * light_dir_factor * atmosphere_density * height_color.a * direction_color.a,
		0.0, 1.0);


	// -------------------------------------------------------------------------
	// Depth
	if (water_density_factor > 0.0) {
		vec2 water_sphere_intersect = ray_sphere_intersect(cam_position, VIEW, max_distance, sea_level);

		if ((water_sphere_intersect.x >= 0.0) && (water_sphere_intersect.y >= 0.0)) {
			float sea_level_depth = sea_level - length(world_pixel_position - NODE_POSITION_WORLD);
			if (sea_level_depth > 0.0) {
				float cam_height = (length(cam_position) - sea_level);

				float water_ray_length = water_sphere_intersect.y - water_sphere_intersect.x;
				float water_ray_length_fac = clamp(abs(water_ray_length * water_density_factor), 0.00, 1.0);
				vec2 depth_uv = vec2(water_ray_length_fac, 0.0);
				vec4 depth_color = texture(water_depth_profile_colors, depth_uv);
				ALBEDO *= depth_color.rgb;
				ALPHA = max(0.0, water_ray_length_fac * depth_color.a);
			}
		}
	}

}
