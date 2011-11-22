#import <Cocoa/Cocoa.h>

@interface MyColorCell : NSCell
{
	NSColor		*_color;
}
- (void) setColor:(NSColor*)color;
- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView*)controlView;

@end	// MyColorCell


@interface MyThumbnailCell : NSCell
{
	NSImage			*_thumbnail;
	NSString		*_filename;
	NSDictionary	*_normalTextAttributes;
	NSDictionary	*_smallerTextAttributes;
}
- (void) setFilename:(NSString*)filename andThumbnail:(NSImage*)thumbnail;
- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView*)controlView;

@end	// MyThumbnailCell
