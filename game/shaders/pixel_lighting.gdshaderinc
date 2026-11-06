uniform vec3 pixel_lantern = vec3(0.0);
uniform float pixel_lantern_strength = 0.0;
uniform vec3 pixel_streets[4];
uniform float pixel_street_strength = 0.0;
varying vec3 pixel_world;
vec3 pixel_local_light(vec3 at){
 float strength=0.0;
 if(pixel_lantern_strength>0.0){
  vec3 d=at-pixel_lantern;
  float falloff=max(0.0,1.0-dot(d,d)/20.25);
  strength+=falloff*falloff*pixel_lantern_strength;
 }
 if(pixel_street_strength>0.0){
  for(int i=0;i<4;i++){
   vec3 d=at-pixel_streets[i];
   float falloff=max(0.0,1.0-dot(d,d)/17.64);
   strength+=falloff*falloff*pixel_street_strength;
  }
 }
 return vec3(1.0,0.70,0.38)*strength;
}
