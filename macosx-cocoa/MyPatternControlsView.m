#import "MyPatternControlsView.h"
#import "StarfishController.h"
#import "StarfishControllerPrivate.h"

@implementation MyPatternControlsView

- (id)initWithFrame:(NSRect)frameRect
{
	[super initWithFrame:frameRect];
	if (self != nil) {
		[self registerForDraggedTypes:[NSArray arrayWithObjects:kStarfishXInfoPBoardType, nil]];
	} // if
	return self;
}

// -----

- (void)drawRect:(NSRect)rect
{
}

// -----

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard		*pboard;
	NSDragOperation		sourceDragMask;
	
	sourceDragMask = [sender draggingSourceOperationMask];
	pboard = [sender draggingPasteboard];
	
	if ([[pboard types] containsObject:kStarfishXInfoPBoardType]) {
		if (sourceDragMask & NSDragOperationCopy)
			return NSDragOperationCopy;
	} // if

	return NSDragOperationNone;
} // draggingEntered:

// -----

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard		*pboard = [sender draggingPasteboard];
	
	if ([[pboard types] containsObject:kStarfishXInfoPBoardType]) {
		// Only a copy operation allowed so just copy the data
		NSString	*info = [NSString stringWithString:[pboard stringForType:kStarfishXInfoPBoardType]];
		[gMainController setPatternControlsFromPatternInfo:info];
	} // if

	return YES;
} // performDragOperation:

// -----

@end
