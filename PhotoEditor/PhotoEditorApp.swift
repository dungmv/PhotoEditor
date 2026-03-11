//
//  PhotoEditorApp.swift
//  PhotoEditor
//
//  Created by Mai Dũng on 11/3/26.
//

import SwiftUI

@main
struct PhotoEditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: PhotoEditorDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
