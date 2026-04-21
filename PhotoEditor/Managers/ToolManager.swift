import SwiftUI
import Combine

struct ToolItem: Tool {
    let id: String
    let name: String
    let iconName: String
    let category: ToolCategory
    let action: (() -> Void)?
    
    init(id: String, name: String, iconName: String, category: ToolCategory = .basic, action: (() -> Void)? = nil) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.category = category
        self.action = action
    }
}

class ToolManager: ObservableObject {
    @Published var activeToolId: String = "select"
    
    let tools: [ToolItem] = [
        ToolItem(id: "select", name: "Select", iconName: "arrow.up.left.precision", category: .basic),
        ToolItem(id: "crop_canvas", name: "Crop Canvas", iconName: "crop", category: .edit),
        ToolItem(id: "crop_layer", name: "Crop Layer", iconName: "crop.rotate", category: .edit),
        ToolItem(id: "filter", name: "Filters", iconName: "f.circle", category: .filter),
        ToolItem(id: "brush", name: "Brush", iconName: "paintbrush", category: .edit),
        ToolItem(id: "text", name: "Text", iconName: "textform", category: .basic)
    ]
    
    var activeTool: ToolItem {
        tools.first { $0.id == activeToolId } ?? tools[0]
    }
}
