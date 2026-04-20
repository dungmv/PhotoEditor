import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

class CIImageProcessor {
    static let shared = CIImageProcessor()
    
    func applyEffect(_ input: CIImage, effect: LayerEffect) -> CIImage {
        let intensity = effect.parameters["intensity"] ?? 0.5
        
        switch effect.type {
        case .brightness:
            let filter = CIFilter.brightnessAndContrast()
            filter.inputImage = input
            filter.brightness = Float(intensity * 2 - 1)
            return filter.outputImage ?? input
        case .contrast:
            let filter = CIFilter.brightnessAndContrast()
            filter.inputImage = input
            filter.contrast = Float(intensity * 2)
            return filter.outputImage ?? input
        case .saturation:
            let filter = CIFilter.colorControls()
            filter.inputImage = input
            filter.saturation = Float(intensity * 2)
            return filter.outputImage ?? input
        case .blur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = input
            filter.radius = Float(intensity * 20)
            return filter.outputImage ?? input
        case .sepia:
            let filter = CIFilter.sepiaTone()
            filter.inputImage = input
            filter.intensity = Float(intensity)
            return filter.outputImage ?? input
        case .invert:
            let filter = CIFilter.colorInvert()
            filter.inputImage = input
            return filter.outputImage ?? input
        case .grayscale:
            let filter = CIFilter.colorControls()
            filter.inputImage = input
            filter.saturation = 0
            return filter.outputImage ?? input
        default:
            return input
        }
    }
}
