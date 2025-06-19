#[compute]

#version 450
// #extension GL_EXT_shader_atomic_float : require

layout(local_size_x = 512, local_size_y = 1, local_size_z = 1) in;

struct MyVec2 {
	vec2 v;
};

layout(set = 0, binding = 0, std430) restrict buffer InPosBuffer {
	MyVec2 data[];
} in_pos_buffer;

layout(set = 0, binding = 1, std430) restrict buffer InVelBuffer {
	MyVec2 data[];
} in_vel_buffer;

layout(set = 0, binding = 2, std430) restrict buffer InMassBuffer {
	float data[];
} in_mass_buffer;

layout(set = 0, binding = 3, std430) restrict buffer OutPosBuffer {
	MyVec2 data[];
} out_pos_data_buffer;

layout(set = 0, binding = 4, std430) restrict buffer OutVelBuffer {
	MyVec2 data[];
} out_vel_data_buffer;

layout(set = 0, binding = 5, std430) restrict buffer OutMassBuffer {
	float data[];
} out_mass_data_buffer;

layout(set = 0, binding = 6, rgba32f) uniform image2D OUTPUT_TEXTURE;

layout(push_constant, std430) uniform Params {
	float run_mode;
	float G;
	float dt;
	int point_count;
} params;

// Function to draw a circle at a given position with a given color and radius
void draw_circle(vec2 center, float radius, vec4 color) {
	int min_x = int(floor(center.x - radius));
	int max_x = int(ceil(center.x + radius));
	int min_y = int(floor(center.y - radius));
	int max_y = int(ceil(center.y + radius));

	for (int x = min_x; x <= max_x; x++) {
		for (int y = min_y; y <= max_y; y++) {
			vec2 pixel_pos = vec2(x, y);
			float distance = length(pixel_pos - center);

			if (distance <= radius) {
				imageStore(OUTPUT_TEXTURE, ivec2(x, y), color);
			}
		}
	}
}

void run_sim() {
	uint pos = gl_GlobalInvocationID.x;
	bool is_center = (pos == 0);
	if (pos > params.point_count) return;	

	// Current object's position, velocity, and mass
	vec2 my_pos = in_pos_buffer.data[pos].v.xy;
	vec2 my_vel = in_vel_buffer.data[pos].v.xy;
	float my_mass = in_mass_buffer.data[pos];

	// Skip if the object has no mass (has been merged)
	if (abs(my_mass) < 0.00001) return;

	out_pos_data_buffer.data[pos].v.xy = my_pos;
	out_vel_data_buffer.data[pos].v.xy = my_vel;
	out_mass_data_buffer.data[pos] = my_mass;

	// Compute this object's radius based on its mass
	float my_radius =  pow(my_mass, 1.0 / 3.0);

	// Initialize force accumulator
	vec2 total_force = vec2(0.0, 0.0);

	// Loop over all other objects to compute gravitational forces and detect collisions
	for (uint i = 0; i < in_pos_buffer.data.length(); i++) {
		if (i != pos) { // Avoid self-interaction

			float other_mass = in_mass_buffer.data[i];
			
			// only if other mass is not empty
			if (abs(other_mass) > 0.00001) {
				vec2 other_pos = in_pos_buffer.data[i].v.xy;

				// Compute the radius of the other object based on its mass
				float other_radius =  pow(other_mass, 1.0 / 3.0);

				// Compute the vector between the two objects
				vec2 direction = other_pos - my_pos;
				float distance = length(direction) + 0.00001; // Add small value to prevent division by zero
			
				// Detect collisions based on the sum of the radii
				float combined_radius = my_radius + other_radius;
				if (distance < combined_radius) {
				
					if (my_mass <= other_mass)
					{
					
						// Handle collision immediately by merging the objects
						float new_mass = my_mass + other_mass;
						vec2 new_velocity = (my_vel * my_mass + in_vel_buffer.data[i].v.xy * other_mass) / new_mass;

						// Merge the two objects: larger one absorbs the smaller one
						uint largerObj = ((my_mass > other_mass) || is_center) ? pos : i;
						uint smallerObj = ((my_mass > other_mass) || is_center) ? i : pos;

						out_mass_data_buffer.data[largerObj] = new_mass; // possible conflict
						out_vel_data_buffer.data[largerObj].v = new_velocity; // possible conflict

						// Zero out the smaller object
						out_mass_data_buffer.data[smallerObj] = 0.0;
						out_vel_data_buffer.data[smallerObj].v = vec2(0.0, 0.0);

						// Early exit if this object has been merged
						if (smallerObj == pos) return;
					
					}
				}
								
				// Compute gravitational force
				float force_magnitude = params.G * (my_mass * other_mass) / (distance * distance);

				// Compute force vector and accumulate it
				vec2 unit_direction = normalize(direction);
				vec2 force = unit_direction * force_magnitude;
				
				//if (i == 0) // hack to only give grav from center obj
				//	total_force += force;
				total_force += force;
			}
		}
	}

	my_pos = out_pos_data_buffer.data[pos].v.xy;
	my_vel = out_vel_data_buffer.data[pos].v.xy;
	my_mass = out_mass_data_buffer.data[pos];

	// Compute the acceleration (a = F / m)
	vec2 acceleration = total_force / my_mass;

	// Update velocity and position
	vec2 new_velocity = my_vel + acceleration * params.dt;
	vec2 new_position = my_pos + new_velocity * params.dt;

	// If it's the center object, it doesn't move
	if (is_center) {
		new_velocity = vec2(0, 0);
		new_position = my_pos;
	}

	// Write back updated values to the output buffers
	out_pos_data_buffer.data[pos].v = new_position;
	out_vel_data_buffer.data[pos].v = new_velocity;
	out_mass_data_buffer.data[pos] = my_mass;
}



float zoom_out_factor = 1.0/1.0;  // Adjust this value for desired zoom level
float zoom_value_min = 0.0;
float zoom_value_max = 2048.0;
void draw_texture() {
    uint pos = gl_GlobalInvocationID.x;
    bool is_center = (pos == 0);
	if (pos > params.point_count-1) return;	
	
    vec2 my_pos = in_pos_buffer.data[pos].v.xy;
    float my_mass = in_mass_buffer.data[pos];
	
    vec2 new_pos = out_pos_data_buffer.data[pos].v.xy;
    float new_mass = out_mass_data_buffer.data[pos];

    // Simple mass scaling
    float radius = pow(new_mass, 1.0 / 3.0);
    float previous_radius = pow(my_mass, 1.0 / 3.0);

    // Scale the positions by the zoom factor and translate to center of the texture
    vec2 scaled_my_pos = (my_pos * zoom_out_factor) + ((vec2(zoom_value_max, zoom_value_max) * 0.5) * (1.0 - zoom_out_factor));
	vec2 scaled_new_pos = (new_pos * zoom_out_factor) + ((vec2(zoom_value_max, zoom_value_max) * 0.5) * (1.0 - zoom_out_factor));

	if (scaled_my_pos.x < zoom_value_min || scaled_my_pos.x > zoom_value_max) return;
	if (scaled_my_pos.y < zoom_value_min || scaled_my_pos.y > zoom_value_max) return;
	
    // Erase previous circle if mass was present
    if (new_mass > 0.0) {
        draw_circle(scaled_my_pos, previous_radius * zoom_out_factor, vec4(0.0, 0.0, 0.0, 0.0)); // Transparent erase
    }

    // Erase if the object has disappeared (mass is now zero)
    if (my_mass > 0.0 && abs(new_mass) < 0.00001) {
        draw_circle(scaled_my_pos, previous_radius * zoom_out_factor, vec4(0.0, 0.0, 0.0, 0.0)); // Transparent erase
    }

    // Draw new object if mass is present
    if (new_mass > 0.0) {
        vec4 my_pixel = vec4(1.0, 1.0, 1.0, 1.0); // Default white

        if (is_center) {
            my_pixel = vec4(1.0, 1.0, 0.0, 1.0); // Center object color
        }
        else if (radius <= 3.0) {
            my_pixel = vec4(0.5, 0.5, 0.5, 1.0); // Tiny object gray
        }
        else if (my_mass > out_mass_data_buffer.data[0] * 0.50000) {
		    my_pixel = vec4(1.0, 1.0, 0.0, 1.0); // Yellow
        }
        else if (my_mass > out_mass_data_buffer.data[0] * 0.06000) {
		    my_pixel = vec4(0.5, 0.8, 1.0, 1.0); // Lt Blue
        }
        else if (my_mass > out_mass_data_buffer.data[0] * 0.05500) {
		    my_pixel = vec4(1.0, 0.5, 0.0, 1.0); // Orange
        }
        else if (my_mass > out_mass_data_buffer.data[0] * 0.00500) {
		    my_pixel = vec4(1.0, 0.0, 1.0, 1.0); // Purple
        }
        else if (my_mass > out_mass_data_buffer.data[0] * 0.00050) {
            my_pixel = vec4(1.0, 1.0, 1.0, 1.0); // White
        }
        else if (my_mass > out_mass_data_buffer.data[0] * 0.00020) {
            my_pixel = vec4(0.0, 1.0, 0.0, 1.0); // Green
        }
        else if (my_mass > out_mass_data_buffer.data[0] * 0.00010) {
            my_pixel = vec4(0.5, 0.5, 1.0, 1.0); // Light blue
        }
        else if (my_mass > out_mass_data_buffer.data[0] * 0.00005) {
            my_pixel = vec4(1.0, 0.5, 0.0, 1.0); // Orange
        }

        // Draw the new circle at the scaled position
		draw_circle(scaled_new_pos, radius * zoom_out_factor, my_pixel);
    }
}

void main() {
	if (params.dt == 0.0)
		return;

	if(params.run_mode==0)
		run_sim();
	else if (params.run_mode==1)
		draw_texture();
}
