shader_type canvas_item;
uniform sampler2D grass:source_color,filter_nearest,repeat_enable;
uniform sampler2D sand:source_color,filter_nearest,repeat_enable;
uniform sampler2D stone:source_color,filter_nearest,repeat_enable;
uniform sampler2D climate:filter_linear,repeat_disable;
uniform vec2 world_origin;
vec3 tile(sampler2D art,vec2 uv){
 vec2 p=fract(uv),q=fract(p+0.5);
 vec2 b=smoothstep(vec2(0.2),vec2(0.5),abs(p-0.5));
 return mix(mix(texture(art,p).rgb,texture(art,vec2(q.x,p.y)).rgb,b.x),mix(texture(art,vec2(p.x,q.y)).rgb,texture(art,q).rgb,b.x),b.y);
}
void fragment(){
 vec2 world=world_origin+UV*512.0;
 vec3 biome=texture(climate,world/vec2(16000.0,12800.0)).rgb;
 vec3 c=tile(grass,world/64.0)*mix(vec3(1.0),vec3(1.08,1.01,0.73),biome.b);
 if(biome.r>0.01)c=mix(c,tile(stone,world/64.0),biome.r);
 if(biome.g>0.01)c=mix(c,tile(sand,world/64.0),biome.g);
 COLOR=vec4(c,1.0);
}
