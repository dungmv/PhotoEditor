import SwiftUI

struct FloatingToolbar: View {
    @ObservedObject var toolManager: ToolManager
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(toolManager.tools) { tool in
                ToolButton(tool: tool, isActive: toolManager.activeToolId == tool.id) {
                    toolManager.activeToolId = tool.id
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.bottom, 20)
    }
}

struct ToolButton: View {
    let tool: ToolItem
    let isActive: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tool.iconName)
                    .font(.system(size: 18, weight: isActive ? .bold : .medium))
                    .foregroundColor(isActive ? .accentColor : .primary)
                
                if isActive || isHovered {
                    Text(tool.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isActive ? .accentColor : .secondary)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hover
            }
        }
        .help(tool.name)
    }
}
