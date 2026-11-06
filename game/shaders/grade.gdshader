shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float strength=1.0;
void fragment(){
 vec3 color=texture(screen_texture,SCREEN_UV).rgb;
 vec2 d=(SCREEN_UV-0.5)*vec2(1.0,0.85);
 float vignette=1.0-smoothstep(0.25,0.76,length(d))*0.15*strength;
 float luma=dot(color,vec3(0.299,0.587,0.114));
 color=mix(vec3(luma),color,1.0+0.045*strength);
 COLOR=vec4(color*mix(vec3(1.0),vec3(1.025,1.006,0.974),strength)*vignette,1.0);
}
