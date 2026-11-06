shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 day_color : source_color = vec3(1.0);
uniform float effects = 1.0;
varying vec3 local_pos;
varying vec3 local_normal;
void vertex() {
 local_pos=VERTEX;
 local_normal=NORMAL;
}
void fragment() {
 vec3 p=local_pos;
 vec2 wall_uv=vec2(abs(local_normal.x)>0.5?p.z:p.x,p.y);
 uvec2 cell=uvec2(ivec2(floor(wall_uv*34.0)));
 uint hash_value=(cell.x*1664525u)^(cell.y*1013904223u);
 hash_value=(hash_value^(hash_value>>16u))*2246822519u;
 hash_value^=hash_value>>13u;
 float grain=float(hash_value&255u)/255.0;
 vec3 color=COLOR.rgb*(1.0+(grain-0.5)*0.024*effects);
 if(UV2.x>0.5 && UV2.x<1.5) color*=1.0-0.06*abs(fract(wall_uv.y*12.0+fract(wall_uv.x*3.0)*0.15)*2.0-1.0)*effects;
 if(UV2.x>1.5 && UV2.x<2.5) {
  vec2 block=wall_uv*vec2(3.6,5.0);
  block.x+=mod(floor(block.y),2.0)*0.5;
  vec2 joint=smoothstep(vec2(0.02),vec2(0.07),fract(block));
  color*=mix(1.0,0.78+0.22*joint.x*joint.y,effects);
 }
 if(UV2.x>2.5 && UV2.x<3.5) {
  vec2 roof=vec2(p.z*5.0,p.x*4.0);
  roof.x+=mod(floor(roof.y),2.0)*0.5;
  color*=1.0-0.20*(1.0-smoothstep(0.02,0.10,fract(roof.y)))*effects;
 }
 float light=0.76+0.24*max(0.0,dot(local_normal,vec3(-0.441,0.735,0.515)));
 ALBEDO=color*day_color*light;
 if(UV2.x>3.5) ALBEDO=mix(ALBEDO,color*vec3(1.0,0.84,0.56),clamp(1.0-day_color.r,0.0,0.8)*effects);
}
