import SwiftUI

protocol Tool: Identifiable {
    var id: String { get }
    var name: String { get }
    var iconName: String { get }
    var category: ToolCategory { get }
    
    func onActivate()
    func onDeactivate()
}

enum ToolCategory: String, CaseIterable {
    case basic = "Basic"
    case transform = "Transform"
    case edit = "Edit"
    case filter = "Filter"
}

extension Tool {
    func onActivate() {}
    func onDeactivate() {}
}
