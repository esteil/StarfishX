#import "MyWindow.h"
#import "StarfishControllerPrivate.h"

@implementation MyWindow

// -----

- (void) sendEvent:(NSEvent*)anEvent 
{
	if ([anEvent type] == NSFlagsChanged) {
		[[self delegate] toggleNewPatternButton:anEvent];
	} //

	[super sendEvent:anEvent];
} // sendEvent:

@end
