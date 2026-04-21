import CoreImage
import AppKit

class CIImageProcessor {
    static let shared = CIImageProcessor()
    
    private var colorAdjustKernel: CIColorKernel?
    private var invertKernel: CIColorKernel?
    private var sepiaKernel: CIColorKernel?
    
    private let metalSource = """
    #include <metal_stdlib>
    using namespace metal;
    #include <CoreImage/CoreImage.h>

    extern "C" {
        namespace coreimage {
            float4 colorAdjustKernel(sample_t s, float brightness, float contrast, float saturation) {
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
            
            float4 invertKernel(sample_t s) {
                return float4(1.0 - s.rgb, s.a);
            }
            
            float4 sepiaKernel(sample_t s, float intensity) {
                float3 sepia = float3(
                    dot(s.rgb, float3(0.393, 0.769, 0.189)),
                    dot(s.rgb, float3(0.349, 0.686, 0.168)),
                    dot(s.rgb, float3(0.272, 0.534, 0.131))
                );
                return float4(mix(s.rgb, sepia, intensity), s.a);
            }
        }
    }
    """
    
    init() {
        if let kernels = try? CIKernel.makeKernels(source: metalSource) {
            for kernel in kernels {
                if let colorKernel = kernel as? CIColorKernel {
                    if colorKernel.name == "colorAdjustKernel" { colorAdjustKernel = colorKernel }
                    else if colorKernel.name == "invertKernel" { invertKernel = colorKernel }
                    else if colorKernel.name == "sepiaKernel" { sepiaKernel = colorKernel }
                }
            }
        }
    }
    
    func applyEffect(_ input: CIImage, effect: LayerEffect) -> CIImage {
        let intensity = effect.parameters["intensity"] ?? 0.5
        
        switch effect.type {
        case .brightness, .contrast, .saturation:
            let brightness = effect.type == .brightness ? Float(intensity * 2 - 1) : 0
            let contrast = effect.type == .contrast ? Float(intensity * 2) : 1
            let saturation = effect.type == .saturation ? Float(intensity * 2) : 1
            
            return colorAdjustKernel?.apply(extent: input.extent, arguments: [input, brightness, contrast, saturation]) ?? input
            
        case .sepia:
            return sepiaKernel?.apply(extent: input.extent, arguments: [input, Float(intensity)]) ?? input
            
        case .invert:
            return invertKernel?.apply(extent: input.extent, arguments: [input]) ?? input
            
        case .blur:
            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(input, forKey: kCIInputImageKey)
            filter?.setValue(intensity * 20, forKey: kCIInputRadiusKey)
            return filter?.outputImage ?? input
            
        case .grayscale:
            return colorAdjustKernel?.apply(extent: input.extent, arguments: [input, Float(0), Float(1), Float(0)]) ?? input
            
        default:
            return input
        }
    }
}
