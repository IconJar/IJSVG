//
//  IJSVGExportUtilities.h
//  IJSVG
//
//  Created by Curtis Hard on 16/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#pragma once
#import <IJSVG/IJSVGExportDocument.h>

NS_ASSUME_NONNULL_BEGIN

// Reorders the existing C attributes without detaching or recreating them.
FOUNDATION_EXPORT void IJSVGExportSortAttributes(IJSVGExportElement* element, double (*rank)(const char* name, NSUInteger count));
FOUNDATION_EXPORT void IJSVGExportSortTreeAttributes(IJSVGExportElement* root, double (*rank)(const char* name, NSUInteger count));

FOUNDATION_EXPORT NSUInteger IJSVGExportChildrenHash(IJSVGExportElement* element);
FOUNDATION_EXPORT BOOL IJSVGExportChildrenEqual(IJSVGExportElement* left, IJSVGExportElement* right);

FOUNDATION_EXPORT void IJSVGExportRemoveDefaultAttributes(IJSVGExportElement* root, NSDictionary<NSString*, NSString*>* defaults, NSSet<NSString*>* inheritableNames);

FOUNDATION_EXPORT NSSet<NSString*>* IJSVGExportReferencedIdentifiers(IJSVGExportDocument* document, NSString* _Nullable (*_Nonnull parseURL)(const char* _Nonnull bytes, NSUInteger length));

FOUNDATION_EXPORT NSDictionary<NSString*, NSString*>* IJSVGExportSharedAttributes(IJSVGExportElement* parent, NSArray<NSString*>* names, NSRange* range);

// Replaces an attached wrapper with its children, retaining their order.
FOUNDATION_EXPORT void IJSVGExportUnwrapElement(IJSVGExportElement* element);

// Groups are ordered by the first repeated occurrence; paths within each group
// retain document order. Paths with vector-effect remain explicit.
FOUNDATION_EXPORT NSArray<NSArray<IJSVGExportElement*>*>* IJSVGExportDuplicatePaths(IJSVGExportDocument* document);

// Fixed exporter queries walk the C tree in document order.
FOUNDATION_EXPORT NSArray<IJSVGExportElement*>* IJSVGExportElementsNamed(IJSVGExportDocument* document, const char* name, const char* _Nullable excludedAttribute);
FOUNDATION_EXPORT NSArray<IJSVGExportNode*>* IJSVGExportAttributesNamed(IJSVGExportDocument* document, const char* _Nonnull const* _Nonnull names, NSUInteger count);
FOUNDATION_EXPORT NSArray<IJSVGExportElement*>* IJSVGExportHiddenElements(IJSVGExportDocument* document);

NS_ASSUME_NONNULL_END
