//
//  LineSpacing.swift
//  MDViewer
//
//  Created by Pierre Oosthuizen on 2026/06/01.
//

import CoreGraphics

enum LineSpacing: String, CaseIterable, Identifiable {

    case compact, normal, relaxed

    var id: String { rawValue }

    var label: String {
        switch self {
            case .compact: return "Compact"
            case .normal:  return "Normal"
            case .relaxed: return "Relaxed"
        }
    }

    /// Line spacing as a multiple of the current font size (em), applied to
    /// the rendered preview's paragraph block style. Scales with text size.
    var em: CGFloat {
        switch self {
            case .compact: return 0.05
            case .normal:  return 0.20
            case .relaxed: return 0.60
        }
    }
}
