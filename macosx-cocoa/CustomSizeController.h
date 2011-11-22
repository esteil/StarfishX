/* CustomSizeController */

#import <Cocoa/Cocoa.h>

@class StarfishController;

@interface CustomSizeController : NSWindowController
{
	NSSize						_size;

	IBOutlet NSButton			*doneButton;
	IBOutlet NSTextField		*heightField;
	IBOutlet NSTextField		*widthField;
	IBOutlet NSTextField		*messageText;
	IBOutlet NSTextField		*altivecText;
}

- (NSSize) doCustomSize:(NSSize)startingSize from:(StarfishController*)sender;

- (IBAction) done:(id)sender;

@end
