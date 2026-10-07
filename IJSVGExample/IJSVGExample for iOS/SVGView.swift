/*
 * SVGView.swift
 * IJSVGExample for iOS
 *
 * Created by François Lamboley on 2024/02/14.
 * Copyright © 2024 Curtis Hard. All rights reserved.
 */

import Foundation
import UIKit

import IJSVG



final class SVGView : UIView {
    
    let svg = IJSVG(named: "Toucan in the Shade")!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        svg.renderingOptions?.renderQuality = .fullResolution
        svg.renderingOptions?.ignoreIntrinsicSize = true
        svg.renderingBackingScaleHelper = { [weak self] in
            return self?.window?.screen.scale ?? UIScreen.main.scale
        }
    }
    
    override func draw(_ rect: CGRect) {
        svg.draw(in: bounds)
    }
    
}
