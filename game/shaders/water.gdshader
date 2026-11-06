shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D art : source_color, filter_nearest, repeat_enable;
uniform sampler2D edits : filter_nearest, repeat_disable;
uniform vec3 day_color : source_color = vec3(1.0);
uniform float effects = 1.0;
varying vec2 world_uv;
void vertex(){ world_uv=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
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
 ALBEDO=(color+vec3(sparkle+foam)*effects)*day_color;
}
