import CoreImage
import Foundation
import AppKit

class RenderPipeline {
    private let context = CIContext()
    
    /// Renders the entire document using a pipeline of nodes
    func render(model: DocumentModel) -> NSImage? {
        // 1. Create a base transparent image of canvas size
        let canvasSize = model.canvasSize
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return nil }
        
        var output: CIImage? = CIImage(color: .clear).cropped(to: CGRect(origin: .zero, size: canvasSize))
        
        // 2. Sort layers by z-index (bottom-up for compositing)
        let sortedLayers = model.layers.sorted { $0.zIndex < $1.zIndex }
        
        // 3. Build and execute pipeline
        for layer in sortedLayers where layer.visible {
            guard let image = model.image(for: layer.id) else { continue }
            
            let node = LayerRenderNode(layer: layer, image: image)
            output = node.process(input: output)
        }
        
        // 4. Final Color Correction or Global Effects can be added here
        
        // 5. Convert back to NSImage
        guard let finalCIImage = output,
              let cgImage = context.createCGImage(finalCIImage, from: CGRect(origin: .zero, size: canvasSize)) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: canvasSize)
    }
}
