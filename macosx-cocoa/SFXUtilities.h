#pragma once
#import <Cocoa/Cocoa.h>

#define IsValidCFArray(obj)			((obj) != nil && CFGetTypeID(obj) == CFArrayGetTypeID())
#define IsValidCFData(obj)			((obj) != nil && CFGetTypeID(obj) == CFDataGetTypeID())
#define IsValidCFDate(obj)			((obj) != nil && CFGetTypeID(obj) == CFDateGetTypeID())
#define IsValidCFDictionary(obj)	((obj) != nil && CFGetTypeID(obj) == CFDictionaryGetTypeID())
#define IsValidCFNumber(obj)		((obj) != nil && CFGetTypeID(obj) == CFNumberGetTypeID())
#define IsValidCFString(obj)		((obj) != nil && CFGetTypeID(obj) == CFStringGetTypeID())
#define IsValidCFBoolean(obj)		((obj) != nil && CFGetTypeID(obj) == CFBooleanGetTypeID())


float		frand(float range);
int			irand(int range);
NSImage*	MakeThumbnailFromImage(NSImage *image, NSSize thumbSize, NSImage *badge);

@interface NSDrawer (my_extensions)
- (BOOL)		drawerIsOpen;
- (BOOL)		drawerIsOpenOrOpening;
@end

