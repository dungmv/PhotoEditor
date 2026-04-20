import SwiftUI

struct CanvasCheckerboard: View {
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

struct ResizeCanvasSheet: View {
    @Binding var widthText: String
    @Binding var heightText: String
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resize Canvas")
                .font(.title2)
                .fontWeight(.bold)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Width")
                        .frame(width: 60, alignment: .leading)
                    TextField("Width", text: $widthText)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("Height")
                        .frame(width: 60, alignment: .leading)
                    TextField("Height", text: $heightText)
                        .textFieldStyle(.roundedBorder)
                }
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .hoverEffect()
                Button("Apply", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 350)
        .background(.regularMaterial)
    }
}
