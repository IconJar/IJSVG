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
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func commonInit() {
        svg.renderingOptions?.renderQuality = .fullResolution
        svg.renderingOptions?.ignoreIntrinsicSize = true
        svg.renderingBackingScaleHelper = {
            return UIScreen.main.scale
        }
    }
    
    override func draw(_ rect: CGRect) {
        svg.draw(in: bounds)
    }
    
}
