//
//  Format.swift
//  MDViewer
//
//  Created by Pierre Oosthuizen on 2026/06/01.
//

import Foundation

enum Format: String, CaseIterable, Identifiable {
    
    case raw, preview
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
            case .raw: return "Raw"
            case .preview: return "Preview"
        }
    }
}
