shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 shelters[16];
uniform float shelter_heights[16];
uniform float rain_strength=1.0;
varying vec3 at;
void vertex(){at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 for(int i=0;i<16;i++){
  vec4 r=shelters[i];
  if(r.z>0.0 && at.x>r.x && at.z>r.y && at.x<r.x+r.z && at.z<r.y+r.w && at.y<shelter_heights[i])discard;
 }
 ALBEDO=vec3(0.60,0.77,0.88);
 ALPHA=0.36*rain_strength;
}
