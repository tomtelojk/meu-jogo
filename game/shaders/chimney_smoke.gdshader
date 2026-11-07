shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
varying float opacity;
void vertex(){
 float phase=fract(TIME*0.12+INSTANCE_CUSTOM.x);
 vec3 origin=MODEL_MATRIX[3].xyz;
 origin.y+=phase*1.9;
 origin.x+=sin(TIME*0.38+INSTANCE_CUSTOM.y)*phase*0.24+phase*0.25;
 origin.z+=sin(TIME*0.27+INSTANCE_CUSTOM.y)*phase*0.12;
 float size=mix(0.20,0.64,phase);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],vec4(origin,1.0));
 VERTEX=vec3(UV-vec2(0.5),0.0)*size;
 opacity=sin(phase*3.14159265)*0.19;
}
void fragment(){
 float shape=1.0-smoothstep(0.22,0.50,length(UV-vec2(0.5)));
 ALBEDO=vec3(0.67,0.66,0.61);
 ALPHA=shape*opacity;
}
