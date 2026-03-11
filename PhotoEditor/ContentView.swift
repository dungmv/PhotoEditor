//
//  ContentView.swift
//  PhotoEditor
//
//  Created by Codex on 11/3/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum EditorTool {
    case select
    case cropCanvas
    case cropLayer
}

struct ContentView: View {
    @Binding private var document: PhotoEditorDocument
    @ObservedObject private var model: DocumentModel
    @Environment(\.undoManager) private var undoManager

    @State private var activeTool: EditorTool = .select
    @State private var cropRect: CGRect?
    @State private var showEmptyHint = true
    @State private var pendingUndoSnapshot: DocumentSnapshot?

    init(document: Binding<PhotoEditorDocument>) {
        _document = document
        _model = ObservedObject(wrappedValue: document.wrappedValue.model)
    }

    var body: some View {
        NavigationSplitView {
            LayerListView(model: model,
                          onDelete: deleteLayers,
                          onDuplicate: duplicateLayer,
                          onMove: moveLayers,
                          onToggleVisibility: toggleVisibility)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
                .toolbar {
                    ToolbarItemGroup {
                        Button(action: addLayerFromImport) {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }
                        Button(action: deleteSelectedLayer) {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(model.activeLayerId == nil)
                        Button(action: duplicateSelectedLayer) {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .disabled(model.activeLayerId == nil)
                    }
                }
        } detail: {
            VStack(spacing: 0) {
                CanvasEditorView(model: model,
                                 activeTool: $activeTool,
                                 cropRect: $cropRect,
                                 onGestureStart: beginGestureUndo,
                                 onGestureEnd: commitGestureUndo)
                if showEmptyHint && !model.hasCanvas {
                    Text("Import an image to start editing")
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar {
                ToolbarItemGroup {
                    Button(action: addLayerFromImport) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    Button(action: exportImage) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!model.hasCanvas)
                }
                ToolbarItemGroup {
                    Button(action: { setTool(.cropCanvas) }) {
                        Label("Crop Canvas", systemImage: "crop")
                    }
                    .disabled(!model.hasCanvas)
                    Button(action: { setTool(.cropLayer) }) {
                        Label("Crop Layer", systemImage: "crop.rotate")
                    }
                    .disabled(model.activeLayerId == nil)
                }
                if activeTool == .cropCanvas || activeTool == .cropLayer {
                    ToolbarItemGroup {
                        Button(action: applyCrop) {
                            Label("Apply Crop", systemImage: "checkmark")
                        }
                        .disabled(cropRect == nil)
                        Button(action: cancelCrop) {
                            Label("Cancel", systemImage: "xmark")
                        }
                    }
                }
            }
            .onChange(of: model.hasCanvas) { _, newValue in
                showEmptyHint = !newValue
            }
            .onAppear {
                showEmptyHint = !model.hasCanvas
            }
        }
    }

    private func setTool(_ tool: EditorTool) {
        activeTool = tool
        cropRect = nil
    }

    private func cancelCrop() {
        activeTool = .select
        cropRect = nil
    }

    private func applyCrop() {
        guard let rect = cropRect, rect.width > 1, rect.height > 1 else { return }
        let before = model.snapshot()

        if activeTool == .cropCanvas {
            model.canvasSize = rect.size
            model.layers = model.layers.map { layer in
                var updated = layer
                updated.transform.position.x -= rect.origin.x
                updated.transform.position.y -= rect.origin.y
                return updated
            }
        } else if activeTool == .cropLayer {
            guard let layerId = model.activeLayerId,
                  let index = model.layers.firstIndex(where: { $0.id == layerId }),
                  let image = model.image(for: layerId) else { return }

            let layer = model.layers[index]
            if let result = cropLayerImage(image: image, layer: layer, cropRect: rect) {
                model.setImage(result.image, for: layerId)
                var updated = layer
                updated.transform.position = result.newPosition
                model.layers[index] = updated
            }
        }

        registerUndo(name: "Crop", before: before)
        cancelCrop()
    }

    private func addLayerFromImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let image = NSImage(contentsOf: url) {
                    insertImageLayer(image)
                }
            }
        }
    }

    private func insertImageLayer(_ image: NSImage) {
        let before = model.snapshot()
        let id = UUID()
        let imagePath = "\(id.uuidString).png"

        if !model.hasCanvas {
            model.canvasSize = image.size
        }

        let center = CGPoint(x: model.canvasSize.width / 2,
                             y: model.canvasSize.height / 2)

        let zIndex = (model.layers.map(\.zIndex).max() ?? -1) + 1
        let layer = LayerModel(id: id,
                               name: "Layer \(model.layers.count + 1)",
                               imagePath: imagePath,
                               transform: TransformModel(position: center,
                                                         scale: CGSize(width: 1, height: 1),
                                                         rotation: 0),
                               visible: true,
                               opacity: 1.0,
                               zIndex: zIndex)
        model.layers.insert(layer, at: 0)
        model.normalizeZIndex()
        model.activeLayerId = id
        model.setImage(image, for: id)
        registerUndo(name: "Add Layer", before: before)
    }

    private func deleteSelectedLayer() {
        guard let layerId = model.activeLayerId else { return }
        deleteLayers([layerId])
    }

    private func deleteLayers(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let before = model.snapshot()
        model.layers.removeAll { ids.contains($0.id) }
        model.normalizeZIndex()
        for id in ids {
            model.images[id] = nil
        }
        if let active = model.activeLayerId, !model.layers.contains(where: { $0.id == active }) {
            model.activeLayerId = model.layers.first?.id
        }
        registerUndo(name: "Delete Layer", before: before)
    }

    private func duplicateSelectedLayer() {
        guard let layerId = model.activeLayerId else { return }
        duplicateLayer(layerId)
    }

    private func duplicateLayer(_ id: UUID) {
        guard let layer = model.layers.first(where: { $0.id == id }),
              let image = model.image(for: id) else { return }
        let before = model.snapshot()
        let newId = UUID()
        let newPath = "\(newId.uuidString).png"
        var copy = layer
        copy.id = newId
        copy.name = "\(layer.name) Copy"
        copy.imagePath = newPath
        copy.zIndex = (model.layers.map(\.zIndex).max() ?? -1) + 1
        model.layers.insert(copy, at: 0)
        model.normalizeZIndex()
        model.activeLayerId = newId
        model.setImage(image, for: newId)
        registerUndo(name: "Duplicate Layer", before: before)
    }

    private func moveLayers(fromOffsets: IndexSet, toOffset: Int) {
        let before = model.snapshot()
        model.layers.move(fromOffsets: fromOffsets, toOffset: toOffset)
        model.normalizeZIndex()
        registerUndo(name: "Reorder Layers", before: before)
    }

    private func toggleVisibility(_ id: UUID) {
        guard let index = model.layers.firstIndex(where: { $0.id == id }) else { return }
        let before = model.snapshot()
        model.layers[index].visible.toggle()
        registerUndo(name: "Toggle Visibility", before: before)
    }

    private func exportImage() {
        guard model.hasCanvas else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "Export.png"

        if panel.runModal() == .OK, let url = panel.url {
            let isJPEG = url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg"
            let image = renderCompositeImage(backgroundColor: isJPEG ? .white : nil)
            let data: Data?

            if isJPEG {
                data = image.jpegData
            } else {
                data = image.pngData
            }

            if let data {
                try? data.write(to: url)
            }
        }
    }

    private func renderCompositeImage(backgroundColor: NSColor?) -> NSImage {
        let size = model.canvasSize
        let width = max(Int(size.width), 1)
        let height = max(Int(size.height), 1)

        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: width,
                                         pixelsHigh: height,
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0) else {
            return NSImage(size: size)
        }

        let ctx = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx

        if let backgroundColor {
            backgroundColor.setFill()
            NSRect(origin: .zero, size: size).fill()
        }

        let sorted = model.layers.sorted { $0.zIndex < $1.zIndex }
        for layer in sorted where layer.visible {
            guard let image = model.image(for: layer.id) else { continue }
            drawLayer(image: image, layer: layer)
        }

        NSGraphicsContext.restoreGraphicsState()
        let result = NSImage(size: size)
        result.addRepresentation(rep)
        return result
    }

    private func drawLayer(image: NSImage, layer: LayerModel) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
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
        image.draw(in: rect)
        context.restoreGState()
    }

    private func cropLayerImage(image: NSImage, layer: LayerModel, cropRect: CGRect) -> (image: NSImage, newPosition: CGPoint)? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let localRect = cropRectInLayerSpace(layer: layer, cropRect: cropRect, imageSize: image.size)
        let imageRect = CGRect(x: -image.size.width / 2,
                               y: -image.size.height / 2,
                               width: image.size.width,
                               height: image.size.height)
        let intersection = imageRect.intersection(localRect)
        guard !intersection.isNull, intersection.width > 1, intersection.height > 1 else {
            return nil
        }

        let scaleX = CGFloat(cgImage.width) / image.size.width
        let scaleY = CGFloat(cgImage.height) / image.size.height

        let cropX = (intersection.origin.x + image.size.width / 2) * scaleX
        let cropY = (intersection.origin.y + image.size.height / 2) * scaleY
        let cropWidth = intersection.width * scaleX
        let cropHeight = intersection.height * scaleY

        let flippedY = CGFloat(cgImage.height) - cropY - cropHeight
        let cropPixels = CGRect(x: cropX, y: flippedY, width: cropWidth, height: cropHeight)

        guard let cropped = cgImage.cropping(to: cropPixels) else { return nil }
        let result = NSImage(cgImage: cropped, size: CGSize(width: intersection.width, height: intersection.height))

        let center = CGPoint(x: intersection.midX, y: intersection.midY)
        let scaled = CGPoint(x: center.x * layer.transform.scale.width,
                             y: center.y * layer.transform.scale.height)
        let rotation = layer.transform.rotation
        let cosValue = cos(rotation)
        let sinValue = sin(rotation)
        let rotatedX = scaled.x * cosValue - scaled.y * sinValue
        let rotatedY = scaled.x * sinValue + scaled.y * cosValue
        let rotated = CGPoint(x: rotatedX, y: rotatedY)
        let newPosition = CGPoint(x: layer.transform.position.x + rotated.x,
                                  y: layer.transform.position.y + rotated.y)
        return (result, newPosition)
    }

    private func cropRectInLayerSpace(layer: LayerModel, cropRect: CGRect, imageSize: CGSize) -> CGRect {
        let transform = layerTransform(layer)
        guard let inverse = transform.invertedIfPossible() else { return .null }

        let points = [
            cropRect.origin,
            CGPoint(x: cropRect.maxX, y: cropRect.minY),
            CGPoint(x: cropRect.maxX, y: cropRect.maxY),
            CGPoint(x: cropRect.minX, y: cropRect.maxY)
        ]
        let localPoints = points.map { $0.applying(inverse) }
        let xs = localPoints.map(\.x)
        let ys = localPoints.map(\.y)
        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max() else {
            return .null
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func layerTransform(_ layer: LayerModel) -> CGAffineTransform {
        CGAffineTransform(translationX: layer.transform.position.x, y: layer.transform.position.y)
            .rotated(by: layer.transform.rotation)
            .scaledBy(x: layer.transform.scale.width, y: layer.transform.scale.height)
    }

    private func registerUndo(name: String, before: DocumentSnapshot) {
        let after = model.snapshot()
        undoManager?.registerUndo(withTarget: model) { model in
            model.restore(snapshot: before)
            self.undoManager?.registerUndo(withTarget: model) { model in
                model.restore(snapshot: after)
            }
        }
        undoManager?.setActionName(name)
    }

    private func beginGestureUndo() {
        if pendingUndoSnapshot == nil {
            pendingUndoSnapshot = model.snapshot()
        }
    }

    private func commitGestureUndo() {
        guard let before = pendingUndoSnapshot else { return }
        pendingUndoSnapshot = nil
        registerUndo(name: "Transform", before: before)
    }
}

private struct LayerListView: View {
    @ObservedObject var model: DocumentModel
    let onDelete: ([UUID]) -> Void
    let onDuplicate: (UUID) -> Void
    let onMove: (IndexSet, Int) -> Void
    let onToggleVisibility: (UUID) -> Void

    var body: some View {
        List {
            ForEach(model.layers) { layer in
                HStack {
                    Button(action: { onToggleVisibility(layer.id) }) {
                        Image(systemName: layer.visible ? "eye" : "eye.slash")
                    }
                    .buttonStyle(.borderless)
                    Text(layer.name)
                        .lineLimit(1)
                    Spacer()
                }
                .contentShape(Rectangle())
                .background(model.activeLayerId == layer.id ? Color.accentColor.opacity(0.2) : Color.clear)
                .onTapGesture {
                    model.activeLayerId = layer.id
                }
                .contextMenu {
                    Button("Duplicate") { onDuplicate(layer.id) }
                    Button("Delete") { onDelete([layer.id]) }
                }
            }
            .onMove(perform: onMove)
        }
    }

}

private struct CanvasEditorView: View {
    @ObservedObject var model: DocumentModel
    @Binding var activeTool: EditorTool
    @Binding var cropRect: CGRect?
    let onGestureStart: () -> Void
    let onGestureEnd: () -> Void

    @State private var dragStartPosition: CGPoint?
    @State private var scaleStartDistance: CGFloat?
    @State private var scaleStartValue: CGSize?
    @State private var rotationStartAngle: Double?
    @State private var rotationStartValue: Double?

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    let sorted = model.layers.sorted { $0.zIndex < $1.zIndex }
                    for layer in sorted where layer.visible {
                        guard let image = model.image(for: layer.id) else { continue }
                        let imageSize = image.size
                        let rect = CGRect(x: -imageSize.width / 2,
                                          y: -imageSize.height / 2,
                                          width: imageSize.width,
                                          height: imageSize.height)
                        var transform = CGAffineTransform(translationX: layer.transform.position.x,
                                                           y: layer.transform.position.y)
                        transform = transform.rotated(by: layer.transform.rotation)
                        transform = transform.scaledBy(x: layer.transform.scale.width,
                                                       y: layer.transform.scale.height)
                        var localContext = context
                        localContext.concatenate(transform)
                        localContext.opacity = layer.opacity
                        localContext.draw(Image(nsImage: image), in: rect)
                    }
                }
                .frame(width: max(model.canvasSize.width, 1),
                       height: max(model.canvasSize.height, 1))
                .background(CanvasCheckerboard())
                .clipped()
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            guard activeTool == .select else { return }
                            let point = value.location
                            if let hit = hitTestLayer(at: point) {
                                model.activeLayerId = hit
                            } else {
                                model.activeLayerId = nil
                            }
                        }
                )

                if activeTool == .select, let layer = selectedLayer, let image = model.image(for: layer.id) {
                    SelectionOverlay(layer: layer,
                                     imageSize: image.size,
                                     onMoveStart: beginMove,
                                     onMoveChange: moveLayer,
                                     onMoveEnd: endGesture,
                                     onScaleStart: beginScale,
                                     onScaleChange: updateScale,
                                     onScaleEnd: endGesture,
                                     onRotateStart: beginRotation,
                                     onRotateChange: updateRotation,
                                     onRotateEnd: endGesture)
                }

                if activeTool == .cropCanvas || activeTool == .cropLayer {
                    CropOverlay(cropRect: $cropRect)
                }
            }
            .frame(width: max(model.canvasSize.width, 1),
                   height: max(model.canvasSize.height, 1))
            .padding(24)
        }
    }

    private var selectedLayer: LayerModel? {
        guard let id = model.activeLayerId else { return nil }
        return model.layers.first(where: { $0.id == id })
    }

    private func hitTestLayer(at point: CGPoint) -> UUID? {
        let candidates = model.layers.sorted { $0.zIndex > $1.zIndex }
        for layer in candidates where layer.visible {
            guard let image = model.image(for: layer.id) else { continue }
            let bounding = transformedBoundingBox(layer: layer, imageSize: image.size)
            if bounding.contains(point) {
                return layer.id
            }
        }
        return nil
    }

    private func transformedBoundingBox(layer: LayerModel, imageSize: CGSize) -> CGRect {
        let rect = CGRect(x: -imageSize.width / 2,
                          y: -imageSize.height / 2,
                          width: imageSize.width,
                          height: imageSize.height)
        let transform = CGAffineTransform(translationX: layer.transform.position.x,
                                           y: layer.transform.position.y)
            .rotated(by: layer.transform.rotation)
            .scaledBy(x: layer.transform.scale.width,
                      y: layer.transform.scale.height)
        let points = [
            rect.origin,
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ].map { $0.applying(transform) }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max() else {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func beginMove() {
        onGestureStart()
    }

    private func endGesture() {
        dragStartPosition = nil
        scaleStartDistance = nil
        scaleStartValue = nil
        rotationStartAngle = nil
        rotationStartValue = nil
        onGestureEnd()
    }

    private func moveLayer(translation: CGSize) {
        guard let id = model.activeLayerId,
              let index = model.layers.firstIndex(where: { $0.id == id }) else { return }
        if dragStartPosition == nil {
            dragStartPosition = model.layers[index].transform.position
        }
        if let start = dragStartPosition {
            model.layers[index].transform.position = CGPoint(x: start.x + translation.width,
                                                             y: start.y + translation.height)
        }
    }

    private func beginScale(startPoint: CGPoint) {
        guard let layer = selectedLayer else { return }
        let center = layer.transform.position
        scaleStartDistance = distance(from: center, to: startPoint)
        scaleStartValue = layer.transform.scale
        onGestureStart()
    }

    private func updateScale(currentPoint: CGPoint) {
        guard let id = model.activeLayerId,
              let index = model.layers.firstIndex(where: { $0.id == id }),
              let startDistance = scaleStartDistance,
              let startScale = scaleStartValue else { return }
        let center = model.layers[index].transform.position
        let currentDistance = max(distance(from: center, to: currentPoint), 1)
        let ratio = currentDistance / max(startDistance, 1)
        let newScale = CGSize(width: max(0.1, startScale.width * ratio),
                              height: max(0.1, startScale.height * ratio))
        model.layers[index].transform.scale = newScale
    }

    private func beginRotation(startPoint: CGPoint) {
        guard let layer = selectedLayer else { return }
        let center = layer.transform.position
        rotationStartAngle = angle(from: center, to: startPoint)
        rotationStartValue = layer.transform.rotation
        onGestureStart()
    }

    private func updateRotation(currentPoint: CGPoint) {
        guard let id = model.activeLayerId,
              let index = model.layers.firstIndex(where: { $0.id == id }),
              let startAngle = rotationStartAngle,
              let startRotation = rotationStartValue else { return }
        let center = model.layers[index].transform.position
        let current = angle(from: center, to: currentPoint)
        let delta = current - startAngle
        model.layers[index].transform.rotation = startRotation + delta
    }

    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }

    private func angle(from a: CGPoint, to b: CGPoint) -> Double {
        atan2(Double(b.y - a.y), Double(b.x - a.x))
    }
}

private struct SelectionOverlay: View {
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
        GeometryReader { _ in
            let bounds = boundingBox()
            Path { path in
                path.addRect(bounds)
            }
            .stroke(Color.accentColor, lineWidth: 1)

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

            handle(at: CGPoint(x: bounds.midX, y: bounds.minY - 24))
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

            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: bounds.width, height: bounds.height)
                .position(x: bounds.midX, y: bounds.midY)
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
        }
    }

    private func boundingBox() -> CGRect {
        let rect = CGRect(x: -imageSize.width / 2,
                          y: -imageSize.height / 2,
                          width: imageSize.width,
                          height: imageSize.height)
        let transform = CGAffineTransform(translationX: layer.transform.position.x,
                                           y: layer.transform.position.y)
            .rotated(by: layer.transform.rotation)
            .scaledBy(x: layer.transform.scale.width,
                      y: layer.transform.scale.height)
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
    }
}

private struct CropOverlay: View {
    @Binding var cropRect: CGRect?
    @State private var dragStart: CGPoint?

    var body: some View {
        GeometryReader { _ in
            if let rect = cropRect {
                Rectangle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 1, dash: [6]))
                    )
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = value.startLocation
                    }
                    if let start = dragStart {
                        let origin = CGPoint(x: min(start.x, value.location.x),
                                             y: min(start.y, value.location.y))
                        let size = CGSize(width: abs(value.location.x - start.x),
                                          height: abs(value.location.y - start.y))
                        cropRect = CGRect(origin: origin, size: size)
                    }
                }
                .onEnded { _ in
                    dragStart = nil
                }
        )
    }
}

private struct CanvasCheckerboard: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let tile: CGFloat = 16
            Canvas { context, _ in
                let cols = Int(size.width / tile) + 1
                let rows = Int(size.height / tile) + 1
                for row in 0..<rows {
                    for col in 0..<cols {
                        let rect = CGRect(x: CGFloat(col) * tile,
                                          y: CGFloat(row) * tile,
                                          width: tile,
                                          height: tile)
                        let isEven = (row + col) % 2 == 0
                        context.fill(Path(rect),
                                     with: .color(isEven ? Color.gray.opacity(0.15) : Color.gray.opacity(0.3)))
                    }
                }
            }
        }
    }
}

private extension CGAffineTransform {
    func invertedIfPossible() -> CGAffineTransform? {
        if isIdentity { return self }
        let determinant = a * d - b * c
        if abs(determinant) < 0.000_001 {
            return nil
        }
        return inverted()
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    var jpegData: Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
    }
}
