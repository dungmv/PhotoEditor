import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Binding private var document: PhotoEditorDocument
    @ObservedObject private var model: DocumentModel
    @StateObject private var toolManager = ToolManager()
    @Environment(\.undoManager) private var undoManager

    @State private var cropRect: CGRect?
    @State private var showEmptyHint = true
    @State private var pendingUndoSnapshot: DocumentSnapshot?
    @State private var showResizeCanvas = false
    @State private var resizeWidthText = ""
    @State private var resizeHeightText = ""
    @State private var zoomScale: CGFloat = 1.0

    init(document: Binding<PhotoEditorDocument>) {
        _document = document
        _model = ObservedObject(wrappedValue: document.wrappedValue.model)
    }

    var body: some View {
        NavigationSplitView {
            LayerSidebar(model: model,
                         onDuplicate: duplicateLayer,
                         onDelete: deleteLayers)
                .navigationSplitViewColumnWidth(min: 240, ideal: 260)
        } detail: {
            ZStack {
                VStack(spacing: 0) {
                    mainCanvasArea
                }
                
                // Floating Toolbar
                VStack {
                    Spacer()
                    FloatingToolbar(toolManager: toolManager)
                }
                
                // Effects Panel (Right Sidebar overlay)
                if toolManager.activeToolId == "filter" {
                    HStack {
                        Spacer()
                        EffectsPanel(model: model)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .shadow(color: .black.opacity(0.1), radius: 20, x: -10, y: 0)
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toolManager.activeToolId)
            .toolbar {
                mainToolbar
            }
            .sheet(isPresented: $showResizeCanvas) {
                ResizeCanvasSheet(widthText: $resizeWidthText,
                                  heightText: $resizeHeightText,
                                  onCancel: { showResizeCanvas = false },
                                  onApply: applyResizeCanvas)
            }
        }
    }

    private var mainCanvasArea: some View {
        VStack(spacing: 0) {
            CanvasEditorView(model: model,
                             activeToolId: toolManager.activeToolId,
                             cropRect: $cropRect,
                             zoomScale: $zoomScale,
                             onGestureStart: beginGestureUndo,
                             onGestureEnd: commitGestureUndo)
            
            if showEmptyHint && !model.hasCanvas {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64))
                        .foregroundStyle(.linearGradient(colors: [.accentColor, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("Ready for your next masterpiece")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Import an image to start editing")
                        .foregroundStyle(.secondary)
                    Button(action: addLayerFromImport) {
                        Label("Import Image", systemImage: "plus")
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
            }
        }
    }

    private var mainToolbar: some ToolbarContent {
        Group {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: addLayerFromImport) {
                    Label("Import", systemImage: "plus")
                }
                .help("Add new image layer")
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: exportImage) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(!model.hasCanvas)
                
                Menu {
                    Button("Resize Canvas...") { prepareResizeCanvas() }
                    Divider()
                    Button("Clear All Layers", role: .destructive) { deleteLayers(model.layers.map(\.id)) }
                } label: {
                    Label("Adjust", systemImage: "slider.horizontal.3")
                }
            }
        }
    }

    // MARK: - Actions

    private func applyResizeCanvas() {
        guard let width = Double(resizeWidthText),
              let height = Double(resizeHeightText),
              width > 1, height > 1 else { return }
        let before = model.snapshot()
        model.canvasSize = CGSize(width: width, height: height)
        registerUndo(name: "Resize Canvas", before: before)
        showResizeCanvas = false
    }
    
    private func prepareResizeCanvas() {
        resizeWidthText = "\(Int(model.canvasSize.width))"
        resizeHeightText = "\(Int(model.canvasSize.height))"
        showResizeCanvas = true
    }

    private func addLayerFromImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = true
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
        if !model.hasCanvas { model.canvasSize = image.size }
        
        let center = CGPoint(x: model.canvasSize.width / 2, y: model.canvasSize.height / 2)
        let zIndex = (model.layers.map(\.zIndex).max() ?? -1) + 1
        
        let layer = LayerModel(id: id,
                               name: "Layer \(model.layers.count + 1)",
                               imagePath: "\(id.uuidString).png",
                               transform: TransformModel(position: center, 
                                                         scale: CGSize(width: 1, height: 1), 
                                                         rotation: 0),
                               zIndex: zIndex)
        
        model.layers.insert(layer, at: 0)
        model.normalizeZIndex()
        model.activeLayerId = id
        model.setImage(image, for: id)
        registerUndo(name: "Add Layer", before: before)
    }

    private func deleteLayers(_ ids: [UUID]) {
        let before = model.snapshot()
        model.layers.removeAll { ids.contains($0.id) }
        model.normalizeZIndex()
        registerUndo(name: "Delete Layers", before: before)
    }

    private func duplicateLayer(_ id: UUID) {
        guard let layer = model.layers.first(where: { $0.id == id }),
              let image = model.image(for: id) else { return }
        let before = model.snapshot()
        let newId = UUID()
        var copy = layer
        copy.id = newId
        copy.name = "\(layer.name) Copy"
        model.layers.insert(copy, at: 0)
        model.normalizeZIndex()
        model.setImage(image, for: newId)
        registerUndo(name: "Duplicate Layer", before: before)
    }

    private func exportImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        if panel.runModal() == .OK, let url = panel.url {
            let image = renderCompositeImage()
            if let data = image.pngData {
                try? data.write(to: url)
            }
        }
    }

    private func renderCompositeImage() -> NSImage {
        let size = model.canvasSize
        let result = NSImage(size: size)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return result }
        
        let ctx = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        
        let sorted = model.layers.sorted { $0.zIndex < $1.zIndex }
        for layer in sorted where layer.visible {
            if let image = model.image(for: layer.id), let cgCtx = ctx?.cgContext {
                Renderer.shared.render(layer: layer, image: image, in: cgCtx)
            }
        }
        
        NSGraphicsContext.restoreGraphicsState()
        result.addRepresentation(rep)
        return result
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
        if pendingUndoSnapshot == nil { pendingUndoSnapshot = model.snapshot() }
    }

    private func commitGestureUndo() {
        guard let before = pendingUndoSnapshot else { return }
        pendingUndoSnapshot = nil
        registerUndo(name: "Transform", before: before)
    }
}

// MARK: - Canvas View

private struct CanvasEditorView: View {
    @ObservedObject var model: DocumentModel
    let activeToolId: String
    @Binding var cropRect: CGRect?
    @Binding var zoomScale: CGFloat
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
                // The Main Canvas
                Canvas { context, size in
                    let sorted = model.layers.sorted { $0.zIndex < $1.zIndex }
                    for layer in sorted where layer.visible {
                        guard let image = model.image(for: layer.id) else { continue }
                        Renderer.shared.render(layer: layer, image: image, in: context.cgContext)
                    }
                }
                .frame(width: max(model.canvasSize.width, 1), height: max(model.canvasSize.height, 1))
                .background(CanvasCheckerboard())
                .clipped()
                .onTapGesture {
                    // Logic to clear selection if background tapped
                    model.activeLayerId = nil
                }

                // Interaction Overlays
                if activeToolId == "select", let selected = selectedLayer, let image = model.image(for: selected.id) {
                    SelectionOverlay(
                        layer: selected,
                        imageSize: image.size,
                        onMoveStart: onGestureStart,
                        onMoveChange: moveLayer,
                        onMoveEnd: onGestureEnd,
                        onScaleStart: beginScale,
                        onScaleChange: updateScale,
                        onScaleEnd: onGestureEnd,
                        onRotateStart: beginRotation,
                        onRotateChange: updateRotation,
                        onRotateEnd: onGestureEnd
                    )
                }
            }
            .scaleEffect(zoomScale, anchor: .topLeading)
            .padding(100) // Extra padding for easier interaction
        }
    }

    private var selectedLayer: LayerModel? {
        model.layers.first { $0.id == model.activeLayerId }
    }

    // MARK: - Gesture Logic

    private func moveLayer(translation: CGSize) {
        guard let id = model.activeLayerId, let index = model.layers.firstIndex(where: { $0.id == id }) else { return }
        if dragStartPosition == nil { dragStartPosition = model.layers[index].transform.position }
        if let start = dragStartPosition {
            model.layers[index].transform.position = CGPoint(x: start.x + translation.width, y: start.y + translation.height)
        }
    }

    private func beginScale(startPoint: CGPoint) {
        guard let layer = selectedLayer else { return }
        scaleStartDistance = distance(from: layer.transform.position, to: startPoint)
        scaleStartValue = layer.transform.scale
        onGestureStart()
    }

    private func updateScale(currentPoint: CGPoint) {
        guard let id = model.activeLayerId, let index = model.layers.firstIndex(where: { $0.id == id }),
              let startDist = scaleStartDistance, let startScale = scaleStartValue else { return }
        let currentDist = max(distance(from: model.layers[index].transform.position, to: currentPoint), 1)
        let ratio = currentDist / max(startDist, 1)
        model.layers[index].transform.scale = CGSize(width: max(0.1, startScale.width * ratio), height: max(0.1, startScale.height * ratio))
    }

    private func beginRotation(startPoint: CGPoint) {
        guard let layer = selectedLayer else { return }
        rotationStartAngle = angle(from: layer.transform.position, to: startPoint)
        rotationStartValue = layer.transform.rotation
        onGestureStart()
    }

    private func updateRotation(currentPoint: CGPoint) {
        guard let id = model.activeLayerId, let index = model.layers.firstIndex(where: { $0.id == id }),
              let startAngle = rotationStartAngle, let startRot = rotationStartValue else { return }
        let current = angle(from: model.layers[index].transform.position, to: currentPoint)
        model.layers[index].transform.rotation = startRot + (current - startAngle)
    }

    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }

    private func angle(from a: CGPoint, to b: CGPoint) -> Double {
        atan2(Double(b.y - a.y), Double(b.x - a.x))
    }
}
