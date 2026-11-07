shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://game/shaders/pixel_lighting.gdshaderinc"
uniform sampler2D art : source_color, filter_nearest, repeat_enable;
uniform sampler2D edits : filter_nearest, repeat_disable;
uniform vec3 day_color : source_color = vec3(1.0);
uniform float effects = 1.0;
uniform sampler2D reflection_map : source_color, filter_linear, repeat_disable;
uniform mat4 reflection_matrix;
uniform float reflection_strength=0.0;
uniform vec3 sky_color : source_color = vec3(0.45,0.63,0.72);
uniform float rain=0.0;
varying vec2 world_uv;
varying vec4 reflection_uv;
void vertex(){
 vec4 world=MODEL_MATRIX*vec4(VERTEX,1.0);
 world_uv=world.xz;pixel_world=world.xyz;
 reflection_uv=reflection_matrix*world;
}
void fragment(){
 vec2 mask_uv=world_uv/vec2(250.0,200.0);
 vec2 edit=texture(edits,mask_uv).rg;
 if(edit.r>0.5 && edit.g<0.5) discard;
 vec2 flow=vec2(sin(world_uv.y*0.25+TIME*0.45)*0.014,TIME*0.014)*effects;
 vec3 base=texture(art,UV+flow).rgb;
 float wave=sin(world_uv.x*6.4+world_uv.y*2.8-TIME*1.2)*sin(world_uv.y*4.5-TIME*0.5);
 float bank=smoothstep(0.86,1.0,abs(UV2.x));
 vec3 color=mix(base*vec3(0.80,1.02,1.09),vec3(0.69,0.84,0.76),bank*0.5);
 float sparkle=pow(max(0.0,wave),18.0)*0.12;
 float foam=bank*smoothstep(0.35,0.85,wave)*0.17;
 vec2 reflected=reflection_uv.xy/max(0.001,abs(reflection_uv.w))*vec2(0.5,-0.5)+0.5;
 reflected+=vec2(wave,sin(world_uv.x*3.0+TIME))*0.006;
 float inside=step(0.0,reflected.x)*step(reflected.x,1.0)*step(0.0,reflected.y)*step(reflected.y,1.0);
 vec3 water=color*day_color;
 water=mix(water,sky_color,0.14*effects);
 if(reflection_strength>0.0)water=mix(water,texture(reflection_map,clamp(reflected,vec2(0.002),vec2(0.998))).rgb,inside*reflection_strength*effects);
 vec2 cell=floor(world_uv*2.4);
 float seed=fract(sin(dot(cell,vec2(12.989,78.233)))*43758.5453);
 float phase=fract(TIME*1.3+seed);
 float ring=1.0-smoothstep(0.025,0.07,abs(length(fract(world_uv*2.4)-0.5)-phase*0.48));
 float drops=ring*(1.0-phase)*rain*0.12;
 ALBEDO=water+vec3(sparkle+foam+drops)*effects*day_color+pixel_local_light(pixel_world)*0.18;
}
