#import "MyTableCells.h"


@implementation MyColorCell

// -----

- (id) init
{
	self = [super initImageCell:nil];

	return self;
} // init

// -----

- (void) dealloc
{
	[_color release];
	[super dealloc];
} // dealloc

// -----

- (id) copyWithZone:(NSZone*)zone
{
	id	newObj = [super copyWithZone:zone];
	((MyColorCell*) newObj)->_color = [_color copyWithZone:zone];
	return newObj;
} // copyWithZone

// -----

- (void) setColor:(NSColor*)color
{
	if (color != _color) {
		[_color release];
		_color = [color retain];
	} // if
} // setColor:

// -----

- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	NSRect	inside = NSInsetRect(cellFrame, 2.0, 2.0);

//	[controlView lockFocus];

	[[NSColor blackColor] set];
	NSFrameRect(cellFrame);
	[_color drawSwatchInRect:inside];

//	[controlView unlockFocus];
} // drawInteriorWithFrame:inView:

// -----

@end


#define kThumbnameFilenamePad		5

@implementation MyThumbnailCell

// -----

- (id) init
{
	self = [super initImageCell:nil];
	_normalTextAttributes  = [[NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName, nil] retain];
	_smallerTextAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:[NSFont labelFontOfSize:[NSFont labelFontSize]], NSFontAttributeName, nil]        retain];
	return self;
} // init

// -----

- (void) dealloc
{
	[_thumbnail release];
	[_filename  release];
	[_normalTextAttributes release];
	[_smallerTextAttributes release];
	[super dealloc];
} // dealloc

// -----

- (id) copyWithZone:(NSZone*)zone
{
	id	newObj = [super copyWithZone:zone];
	((MyThumbnailCell*) newObj)->_thumbnail = [_thumbnail copyWithZone:zone];
	((MyThumbnailCell*) newObj)->_filename  = [_filename copyWithZone:zone];
	((MyThumbnailCell*) newObj)->_normalTextAttributes  = [_normalTextAttributes copyWithZone:zone];
	((MyThumbnailCell*) newObj)->_smallerTextAttributes = [_smallerTextAttributes copyWithZone:zone];
	return newObj;
} // copyWithZone

// -----

- (void) setFilename:(NSString*)filename andThumbnail:(NSImage*)thumbnail
{
	if (filename != _filename) {
		[_filename release];
		_filename = [filename retain];
	} // if
	if (thumbnail != _thumbnail) {
		[_thumbnail release];
		_thumbnail = [thumbnail retain];
	} // if
} // setFilename:andThumbnail:

// -----

- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	NSSize			size   = (_thumbnail != nil ? [_thumbnail size] : NSMakeSize(48.0, 48.0));
	int				yOffset = (cellFrame.size.height - size.height) / 2;
	int				xOffset = (cellFrame.size.height - size.width) / 2;		// Use cellFrame height so image area is square
	NSPoint			pt     = NSMakePoint(cellFrame.origin.x + (float) xOffset, cellFrame.origin.y + size.height + (float) yOffset);
	NSDictionary	*attrib = _normalTextAttributes;

//	[controlView lockFocus];

	if (_thumbnail != nil)
		[_thumbnail compositeToPoint:pt operation:NSCompositeCopy];

	// Make cellFrame the remainder of the cell area
	xOffset = cellFrame.size.height + kThumbnameFilenamePad;
	cellFrame.origin.x += xOffset;
	cellFrame.size.width -= xOffset;

	// Determine the size of the text we're drawing and if it'll fit
	size = [_filename sizeWithAttributes:attrib];
	if (size.width >= cellFrame.size.width) {
//		attrib = _smallerTextAttributes;
//		size = [_filename sizeWithAttributes:attrib];
		size.height *= 2;	// Assume it'll wrap to two lines
	} // if

	yOffset = (cellFrame.size.height - size.height) / 2;
	cellFrame.origin.y += yOffset;
	cellFrame.size.height -= yOffset;
	[_filename drawInRect:cellFrame withAttributes:attrib];

//	[controlView unlockFocus];
} // drawInteriorWithFrame:inView:

// -----

@end
