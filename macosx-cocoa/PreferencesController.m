#import "PreferencesController.h"
#import "StarfishController.h"
#include <sys/time.h>
#include <sys/resource.h>			// For setpriority()

// =====

@interface PreferencesController (private)
- (void)		didEndChangedPrioritySheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
@end

// =====

@implementation PreferencesController

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
	return @"Preferences";
} // windowNibName

// -----

- (void) doEditPreferences:(starfishPrefs*)prefs from:(StarfishController*)sender hasAV:(BOOL)canUseAltivec hasMP:(BOOL)canUseMP
{
	NSWindow	*window = [self window];

	_prefs              = prefs;
	_mainController     = sender;
	_canUseAltivec      = canUseAltivec;
	_canUseMP           = canUseMP;

	// Set the initial values
	[fileFormatPopup    		selectItemAtIndex:(_prefs->saveAsJPEG ? fileFormatJPEG : fileFormatTIFF)];
	[jpegQualitySlider			setFloatValue:_prefs->jpegQuality * 100.0];
	[useAltivecSwitch   		setState:_prefs->useAltivec];
	[useAltivecSwitch   		setEnabled:_canUseAltivec];
	[useMPSwitch        		setState:_prefs->useMP];
	[useMPSwitch        		setEnabled:_canUseMP];
	[lowPrioritySwitch  		setState:_prefs->useLowPriority];
	[autoStartSwitch            setState:_prefs->autoStart];
	[quitWhenDoneSwitch			setEnabled:!_prefs->useAutoStartTimer];
	[quitWhenDoneSwitch         setState:_prefs->quitWhenDone];
	[useTimerSwitch				setEnabled:!_prefs->quitWhenDone];
	[useTimerSwitch             setState:_prefs->useAutoStartTimer];
	[minimizeWhileWaitingSwitch setEnabled:_prefs->useAutoStartTimer];
	[timerUnitPopup             setEnabled:_prefs->useAutoStartTimer];
	[timerAmountField           setEnabled:_prefs->useAutoStartTimer];
	[everyStaticText			setEnabled:_prefs->useAutoStartTimer];
	[minimizeWhileWaitingSwitch setState:_prefs->minimizeWhileWaiting];
	[newOnWakeFromSleepSwitch   setState:_prefs->newOnWakeFromSleep];
	[timerUnitPopup             selectItemAtIndex:_prefs->autoStartTimerUnits];
	[timerAmountField           setIntValue:_prefs->autoStartTimerAmount];
	[checkVersionSwitch 		setState:_prefs->checkVersion];

	[self setVersionCheckStatus];

	// These attributes don't seem to be set properly by InterfaceBuilder
	[checkVersionProgress		setIndeterminate:YES];
	[checkVersionProgress		setDisplayedWhenStopped:NO];
	[checkVersionProgress		setStyle:NSProgressIndicatorSpinningStyle];

	// To set the enabled state of the JPEG quality slider stuff
	[self changedFileFormat:self];

	_editingPrefs = YES;
	[NSApp beginSheet:window modalForWindow:[_mainController mainWindow] modalDelegate:nil didEndSelector:nil contextInfo:nil];
	[NSApp runModalForWindow:window];
	_editingPrefs = NO;
	// Sheet is up here.

	// Save values
	_prefs->saveAsJPEG           = ([fileFormatPopup           indexOfSelectedItem] == fileFormatJPEG);
	_prefs->jpegQuality          = [jpegQualitySlider          floatValue] / 100.0;
	_prefs->useAltivec           = [useAltivecSwitch           state];
	_prefs->useMP                = [useMPSwitch                state];
	_prefs->autoStart            = [autoStartSwitch            state];
	_prefs->quitWhenDone         = [quitWhenDoneSwitch         state];
	_prefs->useAutoStartTimer    = [useTimerSwitch             state];
	_prefs->autoStartTimerAmount = [timerAmountField           intValue];
	_prefs->autoStartTimerUnits  = [timerUnitPopup             indexOfSelectedItem];
	_prefs->minimizeWhileWaiting = [minimizeWhileWaitingSwitch state];
	_prefs->newOnWakeFromSleep   = [newOnWakeFromSleepSwitch   state];
	_prefs->checkVersion         = [checkVersionSwitch         state];

	[NSApp endSheet:window];
	[window orderOut:self];
} // doEditPreferences:from:hasAV:hasMP:versCheckStatus:

// -----

- (IBAction) changedFileFormat:(id)sender
{
	BOOL	enable = ([fileFormatPopup indexOfSelectedItem] == fileFormatJPEG);
	[jpegQualitySlider     setEnabled:enable];
	[qualityStaticText     setEnabled:enable];
	[sliderScaleStaticText setEnabled:enable];
} // changedFileFormat:

// -----

- (IBAction) changedPrioritySwitch:(id)sender
{
	BOOL	newUseLowPriority = [lowPrioritySwitch state];

	if (newUseLowPriority != _prefs->useLowPriority) {
		_prefs->useLowPriority = newUseLowPriority;
		if (!_prefs->useLowPriority) {
			// Tell user they'll need to restart the app to increase the priority.
			NSPanel		*alert;
			alert = NSGetAlertPanel(nil, NSLocalizedString(@"PRIO_CHANGE_MSG", @"This change will take effect the next time you launch StarfishX"),
										 NSLocalizedString(@"OK_BUTTON", @"OK"), nil, nil);
			if (alert != nil) {
				[NSApp beginSheet:alert modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(didEndChangedPrioritySheet:returnCode:contextInfo:) contextInfo:nil];
				[NSApp runModalForWindow:alert];
				// Sheet is up here.
				[NSApp endSheet:alert];
				[alert orderOut:self];
				NSReleaseAlertPanel(alert);
			} // if
		} else
			setpriority(PRIO_PROCESS, 0, 20);		// Set us to low priority.
	} // if
} // changedPrioritySwitch

// -----

- (IBAction) changedQuitWhenDone:(id)sender
{
	BOOL newQuitWhenDone = [quitWhenDoneSwitch state];

	if (newQuitWhenDone != _prefs->quitWhenDone) {
		_prefs->quitWhenDone = newQuitWhenDone;
		if (_prefs->quitWhenDone)
			[useTimerSwitch			setState:NO];
		[useTimerSwitch				setEnabled:!_prefs->quitWhenDone];
	} // if
} // changedQuitWhenDone

// -----

- (IBAction) changedUseTimer:(id)sender
{
	BOOL newUseTimer = [useTimerSwitch state];

	if (newUseTimer != _prefs->useAutoStartTimer) {
		_prefs->useAutoStartTimer = newUseTimer;
		if (_prefs->useAutoStartTimer)
			[quitWhenDoneSwitch		setState:NO];
		[quitWhenDoneSwitch			setEnabled:!_prefs->useAutoStartTimer];
		[minimizeWhileWaitingSwitch setEnabled:_prefs->useAutoStartTimer];
		[timerUnitPopup             setEnabled:_prefs->useAutoStartTimer];
		[timerAmountField           setEnabled:_prefs->useAutoStartTimer];
		[everyStaticText			setEnabled:_prefs->useAutoStartTimer];
	} // if
} // changedUseTimer

// -----

- (IBAction) doCheckVersion:(id)sender
{
	[_mainController doCheckVersion:self];
} // doCheckVersion:

// -----

- (IBAction) done:(id)sender
{
	[NSApp stopModal];
} // done:

// -----

- (BOOL) editingPrefs
{
	return _editingPrefs;
} // editingPrefs

// -----

- (void) handleNewVersionSheet:(NSString*)newVersion
{
	NSBeginAlertSheet(NSLocalizedString(@"NEW_VERS_TITLE", @"New Version!"),
					  NSLocalizedString(@"OK_BUTTON", @"OK"),
					  NSLocalizedString(@"CV_TAKE_ME_THERE", @"Take me there!"),
					  nil, [self window], _mainController, @selector(didEndFoundNewVersionSheet:returnCode:contextInfo:), nil, nil,
					  NSLocalizedString(@"CV_FOUND_NEW_MSG", @"A newer version (%@) of StarfishX is now available!"), newVersion);
} // handleNewVersionSheet

// -----

- (void) setVersionCheckStatus
{
	if (_prefs->versionCheckStatus != nil)
		[versionCheckStatusText setStringValue:_prefs->versionCheckStatus];

	if (_prefs->isCheckingVersion)
		[checkVersionProgress startAnimation:self];
	else
		[checkVersionProgress stopAnimation:self];
} // setVersionCheckStatus:

// -----

@end

// =====

@implementation PreferencesController (private)

// -----

- (void) didEndChangedPrioritySheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
	[NSApp stopModal];
} // didEndChangedPrioritySheet:returnCode:contextInfo:

// -----


@end
