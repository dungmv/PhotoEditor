import CoreImage
import AppKit

class CIImageProcessor {
    static let shared = CIImageProcessor()
    
    private var colorAdjustKernel: CIColorKernel?
    private var invertKernel: CIColorKernel?
    private var sepiaKernel: CIColorKernel?
    
    init() {
        guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
              let data = try? Data(contentsOf: url) else {
            fatalError("❌ default.metallib not found in bundle. Ensure shaders are compiled.")
        }
        
        do {
            colorAdjustKernel = try CIColorKernel(functionName: "colorAdjustKernel", fromMetalLibraryData: data)
            invertKernel = try CIColorKernel(functionName: "invertKernel", fromMetalLibraryData: data)
            sepiaKernel = try CIColorKernel(functionName: "sepiaKernel", fromMetalLibraryData: data)
        } catch {
            fatalError("❌ Failed to initialize kernels: \(error). Did you run without -fcikernel?")
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
