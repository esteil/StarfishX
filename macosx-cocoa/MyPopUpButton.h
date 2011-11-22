/* MyPopUpButton */

#import <Cocoa/Cocoa.h>

@interface MyPopUpButton : NSPopUpButton
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
