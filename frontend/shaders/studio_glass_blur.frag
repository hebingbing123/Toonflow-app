#version 460 core

#include <flutter/runtime_effect.glsl>

uniform sampler2D u_texture;
uniform vec2 u_texture_size;
uniform float u_sigma;

out vec4 frag_color;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_texture_size;
  vec4 sum = vec4(0.0);
  float weight_sum = 0.0;
  for (int x = -2; x <= 2; x++) {
    for (int y = -2; y <= 2; y++) {
      vec2 offset = vec2(float(x), float(y)) * u_sigma / u_texture_size;
      float weight = 1.0;
      sum += texture(u_texture, uv + offset) * weight;
      weight_sum += weight;
    }
  }
  vec4 blurred = sum / weight_sum;
  frag_color = mix(blurred, vec4(0.11, 0.12, 0.16, blurred.a), 0.32);
}
