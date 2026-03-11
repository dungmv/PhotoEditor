//
//  DocumentModel.swift
//  PhotoEditor
//
//  Created by Codex on 11/3/26.
//

import AppKit
import Combine
import SwiftUI

struct TransformModel: Codable, Equatable {
    var position: CGPoint
    var scale: CGSize
    var rotation: Double

    static let identity = TransformModel(position: .zero, scale: CGSize(width: 1, height: 1), rotation: 0)

    enum CodingKeys: String, CodingKey {
        case positionX
        case positionY
        case scaleX
        case scaleY
        case rotation
    }

    init(position: CGPoint, scale: CGSize, rotation: Double) {
        self.position = position
        self.scale = scale
        self.rotation = rotation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let positionX = try container.decode(Double.self, forKey: .positionX)
        let positionY = try container.decode(Double.self, forKey: .positionY)
        let scaleX = try container.decode(Double.self, forKey: .scaleX)
        let scaleY = try container.decode(Double.self, forKey: .scaleY)
        rotation = try container.decode(Double.self, forKey: .rotation)
        position = CGPoint(x: positionX, y: positionY)
        scale = CGSize(width: scaleX, height: scaleY)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(scale.width, forKey: .scaleX)
        try container.encode(scale.height, forKey: .scaleY)
        try container.encode(rotation, forKey: .rotation)
    }
}

struct LayerModel: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var imagePath: String
    var transform: TransformModel
    var visible: Bool
    var opacity: Double
    var zIndex: Int

    init(id: UUID = UUID(),
         name: String,
         imagePath: String,
         transform: TransformModel,
         visible: Bool = true,
         opacity: Double = 1.0,
         zIndex: Int) {
        self.id = id
        self.name = name
        self.imagePath = imagePath
        self.transform = transform
        self.visible = visible
        self.opacity = opacity
        self.zIndex = zIndex
    }
}

struct DocumentSnapshot {
    let canvasSize: CGSize
    let layers: [LayerModel]
    let activeLayerId: UUID?
    let images: [UUID: NSImage]
}

final class DocumentModel: ObservableObject {
    @Published var canvasSize: CGSize
    @Published var layers: [LayerModel]
    @Published var activeLayerId: UUID?
    var images: [UUID: NSImage]

    init(canvasSize: CGSize = .zero,
         layers: [LayerModel] = [],
         activeLayerId: UUID? = nil,
         images: [UUID: NSImage] = [:]) {
        self.canvasSize = canvasSize
        self.layers = layers
        self.activeLayerId = activeLayerId
        self.images = images
    }

    var hasCanvas: Bool {
        canvasSize.width > 0 && canvasSize.height > 0
    }

    func image(for layerId: UUID) -> NSImage? {
        images[layerId]
    }

    func setImage(_ image: NSImage, for layerId: UUID) {
        images[layerId] = image
        objectWillChange.send()
    }

    func snapshot() -> DocumentSnapshot {
        let copiedImages = images.mapValues { image in
            (image.copy() as? NSImage) ?? image
        }
        return DocumentSnapshot(canvasSize: canvasSize,
                                layers: layers,
                                activeLayerId: activeLayerId,
                                images: copiedImages)
    }

    func restore(snapshot: DocumentSnapshot) {
        canvasSize = snapshot.canvasSize
        layers = snapshot.layers
        activeLayerId = snapshot.activeLayerId
        images = snapshot.images
    }

    func normalizeZIndex() {
        layers = layers.enumerated().map { index, layer in
            var updated = layer
            updated.zIndex = layers.count - 1 - index
            return updated
        }
    }
}
