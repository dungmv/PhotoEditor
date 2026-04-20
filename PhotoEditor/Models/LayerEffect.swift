import Foundation

enum EffectType: String, Codable, CaseIterable {
    case brightness = "Brightness"
    case contrast = "Contrast"
    case saturation = "Saturation"
    case exposure = "Exposure"
    case blur = "Blur"
    case sepia = "Sepia"
    case invert = "Invert"
    case grayscale = "Grayscale"
    case customShader = "Custom Shader"
}

struct LayerEffect: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var type: EffectType
    var parameters: [String: Double]
    var isEnabled: Bool = true
    
    static func brightness(_ value: Double) -> LayerEffect {
        LayerEffect(type: .brightness, parameters: ["intensity": value])
    }
}
