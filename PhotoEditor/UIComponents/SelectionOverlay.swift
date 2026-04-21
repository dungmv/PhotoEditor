import SwiftUI
import CoreGraphics

struct SelectionOverlay: View {
    let layer: LayerModel
    let imageSize: CGSize
    let onMoveStart: () -> Void
    let onMoveChange: (CGSize) -> Void
    let onMoveEnd: () -> Void
    let onScaleStart: (CGPoint) -> Void
    let onScaleChange: (CGPoint) -> Void
    let onScaleEnd: () -> Void
    let onRotateStart: (CGPoint) -> Void
    let onRotateChange: (CGPoint) -> Void
    let onRotateEnd: () -> Void

    @State private var didMoveStart = false
    @State private var didScaleStart = false
    @State private var didRotateStart = false

    var body: some View {
        let bounds = boundingBox()
        
        ZStack {
            // Main Selection Box
            Path { path in
                path.addRect(bounds)
            }
            .stroke(Color.accentColor, lineWidth: 1.5)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !didMoveStart {
                            didMoveStart = true
                            onMoveStart()
                        }
                        onMoveChange(value.translation)
                    }
                    .onEnded { _ in
                        didMoveStart = false
                        onMoveEnd()
                    }
            )

            // Scale Handle (Bottom Right)
            handle(at: CGPoint(x: bounds.maxX, y: bounds.maxY))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !didScaleStart {
                                didScaleStart = true
                                onScaleStart(value.startLocation)
                            }
                            onScaleChange(value.location)
                        }
                        .onEnded { _ in
                            didScaleStart = false
                            onScaleEnd()
                        }
                )

            // Rotation Handle (Top Center, offset)
            ZStack {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 1, height: 30)
                    .position(x: bounds.midX, y: bounds.minY - 15)
                
                handle(at: CGPoint(x: bounds.midX, y: bounds.minY - 30))
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !didRotateStart {
                            didRotateStart = true
                            onRotateStart(value.startLocation)
                        }
                        onRotateChange(value.location)
                    }
                    .onEnded { _ in
                        didRotateStart = false
                        onRotateEnd()
                    }
            )
        }
    }

    private func boundingBox() -> CGRect {
        let rect = CGRect(x: -imageSize.width / 2,
                          y: -imageSize.height / 2,
                          width: imageSize.width,
                          height: imageSize.height)
        let transform = CGAffineTransform(translationX: CGFloat(layer.transform.position.x),
                                           y: CGFloat(layer.transform.position.y))
            .rotated(by: CGFloat(layer.transform.rotation))
            .scaledBy(x: CGFloat(layer.transform.scale.width),
                      y: CGFloat(layer.transform.scale.height))
        let points = [
            rect.origin,
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ].map { $0.applying(transform) }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return CGRect(x: xs.min() ?? 0,
                      y: ys.min() ?? 0,
                      width: (xs.max() ?? 0) - (xs.min() ?? 0),
                      height: (ys.max() ?? 0) - (ys.min() ?? 0))
    }

    private func handle(at point: CGPoint) -> some View {
        Circle()
            .stroke(Color.accentColor, lineWidth: 2)
            .background(Circle().fill(Color.white))
            .frame(width: 12, height: 12)
            .position(point)
            .shadow(radius: 2)
    }
}
