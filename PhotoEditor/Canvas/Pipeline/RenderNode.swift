import CoreImage
import Foundation
import AppKit
import CoreGraphics

/// Protocol for any unit of work in the rendering pipeline
protocol RenderNode {
    var id: UUID { get }
    func process(input: CIImage?) -> CIImage?
}

/// A node specifically for applying filters
class FilterNode: RenderNode {
    let id = UUID()
    let effect: LayerEffect
    
    init(effect: LayerEffect) {
        self.effect = effect
    }
    
    func process(input: CIImage?) -> CIImage? {
        guard let input = input, effect.isEnabled else { return input }
        // We reuse the logic from our previous Renderer but encapsulated here
        return CIImageProcessor.shared.applyEffect(input, effect: effect)
    }
}

/// A node for rendering a single layer
class LayerRenderNode: RenderNode {
    let id = UUID()
    let layer: LayerModel
    let image: NSImage
    
    init(layer: LayerModel, image: NSImage) {
        self.layer = layer
        self.image = image
    }
    
    func process(input: CIImage?) -> CIImage? {
        // Convert NSImage to CIImage
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              var output = CIImage(data: bitmap.tiffRepresentation!) else {
            return input
        }
        
        // 1. Apply Per-Layer Effects Pipeline
        for effect in layer.effects {
            let filter = FilterNode(effect: effect)
            if let processed = filter.process(input: output) {
                output = processed
            }
        }
        
        // 2. Apply Transform (Position, Rotation, Scale)
        // Note: CIImage transforms are different from CGContext
        let transform = layerTransform()
        output = output.transformed(by: transform)
        
        // 3. Composite onto input (Bottom-up)
        if let background = input {
            return output.composited(over: background)
        } else {
            return output
        }
    }
    
    private func layerTransform() -> CGAffineTransform {
        // Center the image before transforming
        let translation = CGAffineTransform(translationX: layer.transform.position.x - image.size.width / 2,
                                             y: layer.transform.position.y - image.size.height / 2)
        return translation
            .rotated(by: layer.transform.rotation)
            .scaledBy(x: layer.transform.scale.width, y: layer.transform.scale.height)
    }
}
