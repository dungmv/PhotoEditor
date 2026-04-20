import SwiftUI
import AppKit

/// The entry point for the Canvas Module
struct CanvasModule: View {
    @ObservedObject var model: DocumentModel
    private let pipeline = RenderPipeline()
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1/60)) { context in
            if let renderedImage = pipeline.render(model: model) {
                Image(nsImage: renderedImage)
                    .resizable()
                    .interpolation(.none) // Keep it sharp
                    .frame(width: model.canvasSize.width, height: model.canvasSize.height)
            } else {
                Color.clear
                    .frame(width: model.canvasSize.width, height: model.canvasSize.height)
            }
        }
    }
}

/// A view wrapper that handles the coordinate system and gestures for the Canvas
struct CanvasViewport: View {
    @ObservedObject var model: DocumentModel
    @Binding var zoomScale: CGFloat
    
    var body: some View {
        ZStack {
            CanvasModule(model: model)
                .background(CanvasCheckerboard())
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        }
        .scaleEffect(zoomScale, anchor: .center)
    }
}
