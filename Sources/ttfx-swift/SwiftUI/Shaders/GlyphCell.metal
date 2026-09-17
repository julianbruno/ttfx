#include <metal_stdlib>
using namespace metal;
struct GlyphVertex { float2 position; float2 uv; uint foreground; uint background; };
struct Raster { float4 position [[position]]; float2 uv; float3 foreground; float3 background; };
float3 rgb(uint color) { return float3((color >> 16) & 255, (color >> 8) & 255, color & 255) / 255.0; }
vertex Raster glyphVertex(const device GlyphVertex *vertices [[buffer(0)]], uint index [[vertex_id]]) {
    GlyphVertex v = vertices[index];
    return {float4(v.position, 0, 1), v.uv, rgb(v.foreground), rgb(v.background)};
}
fragment float4 glyphFragment(Raster in [[stage_in]], texture2d<float> atlas [[texture(0)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float coverage = atlas.sample(s, in.uv).r;
    return float4(mix(in.background, in.foreground, coverage), 1);
}
