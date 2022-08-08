//
//  IJSVGTileLayer.h
//  IJSVG
//
//  Created by Curtis Hard on 29/06/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <IJSVG/IJSVGLayer.h>

@interface IJSVGTileLayer : CATiledLayer <IJSVGDrawableLayer> {
@private
    NSMapTable<NSNumber*, CALayer<IJSVGDrawableLayer>*>* _layerUsageMapTable;
}

@end
