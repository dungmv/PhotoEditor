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
                                         conformingTo: .package)
}

struct PhotoEditorDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.photoEditorProject, .png, .jpeg] }

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
            if let image = NSImage(data: data) {
                model = PhotoEditorDocument.makeModel(from: image)
            } else {
                model = DocumentModel()
            }
        } else {
            model = DocumentModel()
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let assetsWrapper = FileWrapper(directoryWithFileWrappers: [:])
        assetsWrapper.preferredFilename = "assets"

        var layerRecords: [LayerModel] = []
        let normalizedLayers = model.layers.enumerated().map { index, layer -> LayerModel in
            var updated = layer
            updated.zIndex = model.layers.count - 1 - index
            return updated
        }

        for layer in normalizedLayers {
            var updated = layer
            let filename = updated.imagePath.isEmpty ? "\(layer.id.uuidString).png" : updated.imagePath
            updated.imagePath = filename

            if let image = model.image(for: layer.id),
               let pngData = image.pngData {
                let fileWrapper = FileWrapper(regularFileWithContents: pngData)
                fileWrapper.preferredFilename = filename
                assetsWrapper.addFileWrapper(fileWrapper)
            }

            layerRecords.append(updated)
        }

        let projectFile = ProjectFile(canvasWidth: model.canvasSize.width,
                                      canvasHeight: model.canvasSize.height,
                                      layers: layerRecords,
                                      activeLayerId: model.activeLayerId)
        let projectData = try JSONEncoder().encode(projectFile)
        let projectWrapper = FileWrapper(regularFileWithContents: projectData)
        projectWrapper.preferredFilename = "project.json"

        let root = FileWrapper(directoryWithFileWrappers: [:])
        root.addFileWrapper(projectWrapper)
        root.addFileWrapper(assetsWrapper)
        root.preferredFilename = "PhotoEditor"
        return root
    }
}

@preconcurrency
struct ProjectFile: Codable {
    var canvasWidth: Double
    var canvasHeight: Double
    var layers: [LayerModel]
    var activeLayerId: UUID?
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
