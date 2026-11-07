shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D art : source_color, filter_nearest;
uniform vec3 light_direction=vec3(0.4,-0.8,0.3);
uniform float opacity=0.27;
void vertex(){
 vec3 root=MODEL_MATRIX[3].xyz;
 vec3 right=normalize(MAIN_CAM_INV_VIEW_MATRIX[0].xyz);
 vec3 up=normalize(MAIN_CAM_INV_VIEW_MATRIX[1].xyz);
 vec3 world=root+right*VERTEX.x+up*VERTEX.y;
 float height=max(0.0,world.y-root.y);
 vec3 ray=vec3(light_direction.x,min(-0.3,light_direction.y),light_direction.z);
 world+=ray*(-height/ray.y);
 world.y=root.y;
 VERTEX=(inverse(MODEL_MATRIX)*vec4(world,1.0)).xyz;
}
void fragment(){
 vec4 c=texture(art,UV);
 if(c.a<0.12 || min(c.r,c.b)-c.g>0.18) discard;
 ALBEDO=vec3(0.025,0.035,0.045);
 ALPHA=c.a*opacity;
}
