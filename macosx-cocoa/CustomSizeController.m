#import "CustomSizeController.h"
#import "StarfishController.h"

// =====

@interface CustomSizeController (private)
- (BOOL) control:(NSControl*)control textShouldEndEditing:(NSText*)fieldEditor;
- (void) controlTextDidChange:(NSNotification*)aNotification;
@end

// =====

@implementation CustomSizeController

// -----

- (id) init
{
	self = [super init];

	return self;
} // init

// -----

- (void) dealloc
{
	[super dealloc];
} // dealloc

// -----

- (NSString*) windowNibName
{
	return @"CustomSize";
} // windowNibName

// -----

- (NSSize) doCustomSize:(NSSize)startingSize from:(StarfishController*)sender
{
	NSWindow	*window = [self window];

	_size = startingSize;

	// Set the initial values
    [heightField setIntValue:_size.height];
    [widthField  setIntValue:_size.width];
    [self controlTextDidChange:nil];
    [[self window] makeFirstResponder:widthField];

	[NSApp beginSheet:window modalForWindow:[sender mainWindow] modalDelegate:nil didEndSelector:nil contextInfo:nil];
	[NSApp runModalForWindow:window];
	// Sheet is up here.

	[NSApp endSheet:window];
	[window orderOut:self];

	return _size;
} // doCustomSize:

// -----

- (IBAction) done:(id)sender
{
	BOOL	validated = YES;

	// Save values
	_size.height = [heightField intValue];
	_size.width  = [widthField  intValue];

	if (_size.height < 16) {
		validated = NO;
		[heightField setIntValue:16];
		[[self window] makeFirstResponder:heightField];
	} // if
	if (_size.width < 16) {
		validated = NO;
		[widthField setIntValue:16];
		[[self window] makeFirstResponder:widthField];
	} // if

	if (validated)
		[NSApp stopModal];
	else
		SysBeep(1);
} // done:

// -----

@end

// =====

@implementation CustomSizeController (private)

// -----

- (BOOL) control:(NSControl*)control textShouldEndEditing:(NSText*)fieldEditor;
{
	BOOL	isOK = YES;

	if (control == heightField || control == widthField) {
		if ([control intValue] < 16) {
			[control setIntValue:16];
			isOK = NO;
		} // if
	} // if

	return isOK;
} // control:textShouldEndEditing

// -----

- (void) controlTextDidChange:(NSNotification*)aNotification
{
	float		mbRequired;

	_size.height = [heightField intValue];
	_size.width  = [widthField  intValue];
	mbRequired = (_size.height * _size.width * 4) / (1024 * 1024);
	if (mbRequired >= 8.0)
		[messageText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"HUGE_IMAGE", @"This image will require %.2fMB of RAM to create."), mbRequired]];
	else
		[messageText setStringValue:@""];

#if BUILD_ALTIVEC
	int			extra;
	extra = ((int) _size.width) % PIXELS_PER_CALL;
	if (extra != 0)
		[altivecText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"ALTIVEC_ROUNDED_SIZE", @"When using Altivec, the width will be rounded down to a multiple of %d pixels (i.e., %d pixels)."), PIXELS_PER_CALL, (int) _size.width - extra]];
	else
#endif
		[altivecText setStringValue:@""];
} // controlTextDidChange:


@end
