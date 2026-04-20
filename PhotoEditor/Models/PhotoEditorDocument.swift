//
//  PhotoEditorDocument.swift
//  PhotoEditor
//
//  Created by Codex on 11/3/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let photoEditorProject = UTType(exportedAs: "com.nexgen.photoeditor.project",
                                           conformingTo: .json)
}

struct PhotoEditorDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.photoEditorProject, .png, .jpeg] }
    static var writableContentTypes: [UTType] { [.photoEditorProject] }

    var model: DocumentModel

    init() {
        model = DocumentModel()
    }

    init(configuration: ReadConfiguration) throws {
        let wrapper = configuration.file
        if wrapper.isDirectory, let fileWrappers = wrapper.fileWrappers {
            let projectData = fileWrappers["project.json"]?.regularFileContents
            let assetsWrapper = fileWrappers["assets"]
            let projectFile = try projectData.map { try JSONDecoder().decode(ProjectFile.self, from: $0) }

            let canvasSize = CGSize(width: projectFile?.canvasWidth ?? 0,
                                    height: projectFile?.canvasHeight ?? 0)
            let layers = (projectFile?.layers ?? []).sorted(by: { (lhs: LayerModel, rhs: LayerModel) in
                lhs.zIndex > rhs.zIndex
            })
            let activeLayerId = projectFile?.activeLayerId
            var images: [UUID: NSImage] = [:]

            if let assetFiles = assetsWrapper?.fileWrappers {
                for layer in layers {
                    let filename = layer.imagePath.replacingOccurrences(of: "assets/", with: "")
                    if let data = assetFiles[filename]?.regularFileContents,
                       let image = NSImage(data: data) {
                        images[layer.id] = image
                    }
                }
            }

            model = DocumentModel(canvasSize: canvasSize,
                                  layers: layers,
                                  activeLayerId: activeLayerId,
                                  images: images)
        } else if wrapper.isRegularFile, let data = wrapper.regularFileContents {
            if let project = try? JSONDecoder().decode(ProjectFileV2.self, from: data) {
                let canvasSize = CGSize(width: project.canvasWidth, height: project.canvasHeight)
                var images: [UUID: NSImage] = [:]
                let layers = project.layers.map { entry -> LayerModel in
                    if let imageData = entry.imageData,
                       let image = NSImage(data: imageData) {
                        images[entry.layer.id] = image
                    }
                    return entry.layer
                }
                model = DocumentModel(canvasSize: canvasSize,
                                      layers: layers,
                                      activeLayerId: project.activeLayerId,
                                      images: images)
            } else if let image = NSImage(data: data) {
                model = PhotoEditorDocument.makeModel(from: image)
            } else {
                model = DocumentModel()
            }
        } else {
            model = DocumentModel()
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var layerRecords: [LayerFile] = []
        let normalizedLayers = model.layers.enumerated().map { index, layer -> LayerModel in
            var updated = layer
            updated.zIndex = model.layers.count - 1 - index
            return updated
        }

        for layer in normalizedLayers {
            var updated = layer
            if updated.imagePath.isEmpty {
                updated.imagePath = "\(layer.id.uuidString).png"
            }
            let imageData = model.image(for: layer.id)?.pngData
            layerRecords.append(LayerFile(layer: updated, imageData: imageData))
        }

        let projectFile = ProjectFileV2(formatVersion: 2,
                                        canvasWidth: model.canvasSize.width,
                                        canvasHeight: model.canvasSize.height,
                                        layers: layerRecords,
                                        activeLayerId: model.activeLayerId)
        let projectData = try JSONEncoder().encode(projectFile)
        return FileWrapper(regularFileWithContents: projectData)
    }
}

@preconcurrency
struct ProjectFile: Codable {
    var canvasWidth: Double
    var canvasHeight: Double
    var layers: [LayerModel]
    var activeLayerId: UUID?
}

@preconcurrency
struct ProjectFileV2: Codable {
    var formatVersion: Int
    var canvasWidth: Double
    var canvasHeight: Double
    var layers: [LayerFile]
    var activeLayerId: UUID?
}

@preconcurrency
struct LayerFile: Codable {
    var layer: LayerModel
    var imageData: Data?
}

private extension PhotoEditorDocument {
    static func makeModel(from image: NSImage) -> DocumentModel {
        let id = UUID()
        let size = image.size
        let layer = LayerModel(id: id,
                               name: "Layer 1",
                               imagePath: "\(id.uuidString).png",
                               transform: TransformModel(position: CGPoint(x: size.width / 2,
                                                                           y: size.height / 2),
                                                         scale: CGSize(width: 1, height: 1),
                                                         rotation: 0),
                               visible: true,
                               opacity: 1.0,
                               zIndex: 0)
        return DocumentModel(canvasSize: size,
                             layers: [layer],
                             activeLayerId: id,
                             images: [id: image])
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}
