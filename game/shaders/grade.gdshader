shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float strength=1.0;
uniform float focus_y=0.5;
uniform float dof_strength=1.0;
uniform float bloom_strength=0.22;
uniform vec2 pixel_size=vec2(0.001);
float highlight(vec3 color){
 float white=min(color.r,min(color.g,color.b));
 return clamp(smoothstep(0.0,0.08,color.r-color.g)+smoothstep(0.88,0.98,white),0.0,1.0);
}
void fragment(){
 vec3 color=texture(screen_texture,SCREEN_UV).rgb;
 float coc=smoothstep(0.16,0.40,abs(SCREEN_UV.y-focus_y))*dof_strength;
 vec2 radius=pixel_size*mix(2.0,4.5,coc);
 vec3 blurred=color*0.2;
 vec3 glow=max(color-vec3(0.73),vec3(0.0))*0.2*highlight(color);
 for(int y=-1;y<=1;y++){
  for(int x=-1;x<=1;x++){
   if(x==0 && y==0)continue;
   vec3 tap=texture(screen_texture,SCREEN_UV+vec2(float(x),float(y))*radius).rgb;
   blurred+=tap*0.1;
   glow+=max(tap-vec3(0.73),vec3(0.0))*0.1*highlight(tap);
  }
 }
 color=mix(color,blurred,coc)+glow*bloom_strength*2.8;
 vec2 d=(SCREEN_UV-0.5)*vec2(1.0,0.85);
 float vignette=1.0-smoothstep(0.25,0.76,length(d))*0.15*strength;
 float luma=dot(color,vec3(0.299,0.587,0.114));
 color=mix(vec3(luma),color,1.0+0.045*strength);
 COLOR=vec4(color*mix(vec3(1.0),vec3(1.025,1.006,0.974),strength)*vignette,1.0);
}
