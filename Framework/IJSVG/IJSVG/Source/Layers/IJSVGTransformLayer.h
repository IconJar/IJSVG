//
//  IJSVGTransformLayer.h
//  IJSVG
//
//  Created by Curtis Hard on 31/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <IJSVG/IJSVGLayer.h>

@interface IJSVGTransformLayer : CATransformLayer <IJSVGDrawableLayer> {
@private
    NSMapTable<NSNumber*, CALayer<IJSVGDrawableLayer>*>* _layerUsageMapTable;
}

@end
