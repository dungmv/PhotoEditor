#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

extern "C" {
    namespace coreimage {
        
        [[ stitchable ]] float4 colorAdjustKernel(sample_t s, float brightness, float contrast, float saturation) {
            float4 color = s.rgba;
            // Brightness
            color.rgb += brightness;
            // Contrast
            color.rgb = (color.rgb - 0.5) * contrast + 0.5;
            // Saturation
            float luma = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
            color.rgb = mix(float3(luma), color.rgb, saturation);
            return color;
        }
        
        [[ stitchable ]] float4 invertKernel(sample_t s) {
            return float4(1.0 - s.rgb, s.a);
        }
        
        [[ stitchable ]] float4 sepiaKernel(sample_t s, float intensity) {
            float3 sepia = float3(
                dot(s.rgb, float3(0.393, 0.769, 0.189)),
                dot(s.rgb, float3(0.349, 0.686, 0.168)),
                dot(s.rgb, float3(0.272, 0.534, 0.131))
            );
            return float4(mix(s.rgb, sepia, intensity), s.a);
        }
    }
}
 
