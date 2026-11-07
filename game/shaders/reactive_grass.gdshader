shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://game/shaders/pixel_lighting.gdshaderinc"
uniform vec3 hero = vec3(-1000.0);
uniform vec3 day_color : source_color = vec3(1.0);
uniform float wind_strength=0.55;
uniform float wetness=0.0;
void vertex(){
 vec3 root=MODEL_MATRIX[3].xyz;
 vec2 away=root.xz-hero.xz;
 float distance_to_hero=length(away);
 float bend=(1.0-smoothstep(0.12,0.72,distance_to_hero))*(1.0-smoothstep(0.3,0.7,abs(root.y-hero.y)));
 float tip=UV.y;
 VERTEX.xz+=away/max(distance_to_hero,0.04)*bend*0.32*tip;
 VERTEX.y*=1.0-bend*0.5;
 VERTEX.x+=sin(TIME*1.5+root.x*0.8+root.z*0.6)*0.045*wind_strength*tip;
 VERTEX.z+=cos(TIME*1.1+root.z)*0.025*wind_strength*tip;
 pixel_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
 ALBEDO=COLOR.rgb*(1.0-wetness*0.16)*(day_color+pixel_local_light(pixel_world));
}
