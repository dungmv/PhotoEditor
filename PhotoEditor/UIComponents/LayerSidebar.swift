import SwiftUI

struct LayerSidebar: View {
    @ObservedObject var model: DocumentModel
    let onDuplicate: (UUID) -> Void
    let onDelete: ([UUID]) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            List {
                ForEach(model.layers) { layer in
                    LayerRow(layer: layer,
                             isActive: model.activeLayerId == layer.id,
                             thumbnail: model.image(for: layer.id),
                             onSelect: { model.activeLayerId = layer.id },
                             onToggleVisibility: { toggleVisibility(layer.id) })
                    .contextMenu {
                        Button("Duplicate") { onDuplicate(layer.id) }
                        Divider()
                        Button("Delete", role: .destructive) { onDelete([layer.id]) }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: moveLayers)
            }
            .listStyle(.sidebar)
        }
    }
    
    private var header: some View {
        HStack {
            Text("Layers")
                .font(.headline)
            Spacer()
            Button(action: {}) {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    private func toggleVisibility(_ id: UUID) {
        if let index = model.layers.firstIndex(where: { $0.id == id }) {
            model.layers[index].visible.toggle()
        }
    }
    
    private func moveLayers(fromOffsets: IndexSet, toOffset: Int) {
        model.layers.move(fromOffsets: fromOffsets, toOffset: toOffset)
        model.normalizeZIndex()
    }
}

struct LayerRow: View {
    let layer: LayerModel
    let isActive: Bool
    let thumbnail: NSImage?
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Visibility Toggle
            Button(action: onToggleVisibility) {
                Image(systemName: layer.visible ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(layer.visible ? .secondary : .red.opacity(0.6))
                    .font(.system(size: 11))
                    .frame(width: 20)
            }
            .buttonStyle(.plain)
            
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.1))
                
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .frame(width: 40, height: 40)
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(layer.name)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                
                if !layer.effects.isEmpty {
                    Text("\(layer.effects.count) effects")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isActive {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
