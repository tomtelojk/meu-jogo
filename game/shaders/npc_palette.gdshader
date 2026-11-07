shader_type canvas_item;

// Indexed artwork is sampled without sRGB conversion. The palette contains
// real colors and can be replaced without rebuilding any sprite poses.
uniform sampler2D index_art : filter_nearest, repeat_disable;
uniform sampler2D palette_map : source_color, filter_nearest, repeat_disable;
varying vec4 actor_tint;
void vertex(){actor_tint=COLOR;}
void fragment(){
 vec4 pixel=texture(index_art,UV);
 float index=floor(pixel.r*255.0+0.5);
 vec4 color=texture(palette_map,vec2((index+0.5)/32.0,0.5));
 COLOR=vec4(color.rgb,color.a*pixel.a)*actor_tint;
}
