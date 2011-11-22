/* MyTextField */

#import <Cocoa/Cocoa.h>

@interface MyTextField : NSTextField
{
	id				_dragTarget;
	SEL				_dragAction;
	NSPasteboard	*_dragPboard;
}

- (void)		setDragAction:(SEL)sel;
- (void)		setDragTarget:(id)obj;
- (void)		setDragTypes:(NSArray*)types;
- (NSString*)	dragStringForType:(NSString*)dataType;

@end
