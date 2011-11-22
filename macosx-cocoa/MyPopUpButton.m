#import "MyPopUpButton.h"

@implementation MyPopUpButton

// -----

- (void) setDragAction:(SEL)sel
{
	_dragAction = sel;
} // setDragAction:

// -----

- (void) setDragTarget:(id)obj
{
	_dragTarget = obj;
} // setDragTarget:

// -----

- (void) setDragTypes:(NSArray*)types
{
	[self registerForDraggedTypes:types];
} // setDragTypes

// -----

- (NSString*) dragStringForType:(NSString*)dataType
{
	NSString	*data = nil;

	if (_dragPboard != nil && [[_dragPboard types] containsObject:dataType])
		data = [NSString stringWithString:[_dragPboard stringForType:dataType]];

	return data;
} // dragDataForType

// -----

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard		*pboard;
	NSDragOperation		sourceDragMask;
	
	sourceDragMask = [sender draggingSourceOperationMask];
	pboard = [sender draggingPasteboard];
	
	if (sourceDragMask & NSDragOperationCopy)
		return NSDragOperationCopy;

	return NSDragOperationNone;
} // draggingEntered:

// -----

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
	_dragPboard = [sender draggingPasteboard];
	
	if (_dragPboard != nil && _dragTarget != nil && [_dragTarget respondsToSelector:_dragAction])
		[_dragTarget performSelector:_dragAction withObject:self];

	_dragPboard = nil;

	return YES;
} // performDragOperation:

// -----

@end
