import AppKit
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

class Renderer {
    static let shared = Renderer()
    private let context = CIContext()
    
    func render(layer: LayerModel, image: NSImage, in context: CGContext) {
        let size = image.size
        let rect = CGRect(x: -size.width / 2,
                          y: -size.height / 2,
                          width: size.width,
                          height: size.height)
        
        context.saveGState()
        context.translateBy(x: layer.transform.position.x, y: layer.transform.position.y)
        context.rotate(by: layer.transform.rotation)
        context.scaleBy(x: layer.transform.scale.width, y: layer.transform.scale.height)
        context.setAlpha(layer.opacity)
        
        var processedImage = image
        if !layer.effects.isEmpty {
            processedImage = applyEffects(to: image, effects: layer.effects)
        }
        
        processedImage.draw(in: rect)
        context.restoreGState()
    }
    
    private func applyEffects(to image: NSImage, effects: [LayerEffect]) -> NSImage {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              var ciImage = CIImage(data: bitmap.tiffRepresentation!) else {
            return image
        }
        
        for effect in effects where effect.isEnabled {
            ciImage = applyEffect(ciImage, effect: effect)
        }
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return image
        }
        
        return NSImage(cgImage: cgImage, size: image.size)
    }
    
    private func applyEffect(_ input: CIImage, effect: LayerEffect) -> CIImage {
        let intensity = effect.parameters["intensity"] ?? 0.5
        
        switch effect.type {
        case .brightness:
            let filter = CIFilter.brightnessAndContrast()
            filter.inputImage = input
            filter.brightness = Float(intensity * 2 - 1) // -1 to 1
            return filter.outputImage ?? input
        case .contrast:
            let filter = CIFilter.brightnessAndContrast()
            filter.inputImage = input
            filter.contrast = Float(intensity * 2) // 0 to 2
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
