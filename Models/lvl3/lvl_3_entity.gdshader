shader_type spatial;
// unshaded removes realistic lighting for a flat, liminal look.
render_mode unshaded, depth_draw_opaque;

uniform vec4 slime_color : source_color = vec4(0.4, 0.8, 0.4, 0.5);
uniform float wobble_speed = 4.0;
uniform float wobble_intensity = 0.08;

// PS1 hardware limitations
uniform float jitter_resolution = 100.0; // Lower = more intense vertex snapping

// Dreamcore Eerie Mouth
uniform vec4 mouth_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float smile_width = 0.22;
uniform float smile_curve = 4.0;
uniform float smile_thickness = 0.015;
uniform float smile_y_offset = 0.05;

void vertex() {
    // 1. Organic Wobble
    vec3 pos = VERTEX;
    pos.x += sin(TIME * wobble_speed + pos.y * 5.0) * wobble_intensity;
    pos.z += cos(TIME * wobble_speed + pos.y * 5.0) * wobble_intensity;
    
    // 2. PS1 Vertex Snapping (Jitter)
    // Project into clip space (screen space) to snap to a low-res grid
    vec4 clip_pos = PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX * vec4(pos, 1.0);
    clip_pos.xyz = round(clip_pos.xyz * jitter_resolution) / jitter_resolution;
    
    POSITION = clip_pos;
}

void fragment() {
    // Base Color
    ALBEDO = slime_color.rgb;
    ALPHA = slime_color.a;

    // 3. Procedural Dreamcore Void Mouth
    // Center the UV coordinates (0,0 is the middle of the sphere face)
    vec2 centered_uv = UV - vec2(0.5, 0.5);
    
    // Godot UV.y goes down. To make a U-shaped smile, we invert the curve.
    float curve = (centered_uv.x * centered_uv.x) * -smile_curve;
    float target_y = curve + smile_y_offset;
    
    // Check if the current pixel falls on the smile line
    if (abs(centered_uv.x) < smile_width) {
        if (abs(centered_uv.y - target_y) < smile_thickness) {
            ALBEDO = mouth_color.rgb;
            ALPHA = 1.0; // Solid void
        }
    }
    
    // 4. PS1 Screen-Door Transparency
    // Early 3D hardware used a checkerboard pattern to fake transparency.
    if (ALPHA < 0.99) {
        // Discard every other pixel based on screen coordinates
        if (mod(FRAGCOORD.x + FRAGCOORD.y, 2.0) < 1.0) {
            discard;
        }
        // Force remaining pixels to be fully opaque
        ALPHA = 1.0; 
    }
}