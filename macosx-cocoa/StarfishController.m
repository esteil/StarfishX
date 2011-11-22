/*

Copyright 2003 M. Scott Marcy
All Rights Reserved

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/

#import "StarfishController.h"
#import "StarfishGenerator.h"
#import "CustomSizeController.h"
#import "EditPalettesController.h"
#import "PreferencesController.h"
#import "MyTableCells.h"
#import "StarfishControllerPrivate.h"
#import "SFXUtilities.h"

#include <sys/time.h>
#include <sys/resource.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>


#define kControlsDrawerHeight	202
#define kControlsDrawerFudge	100
#define kDrawerWidthPad			 12

extern NSString		*gVersCheckingString;		// Defined in StarfishController-VersCheck.m
StarfishController	*gMainController;
io_connect_t		gRootPort;


static BOOL 		CanUseAltivec(void);
static int			CountProcessors(void);
static BOOL			UnsignedIntValueFromString(NSString *str, UInt32 *value, int *len);
static void			SystemPowerNotificationCallback(void *x, io_service_t y, natural_t messageType, void *messageArgument);



///////////////////////////////////////////////
// Public Implementation--StarfishController //
///////////////////////////////////////////////

@implementation StarfishController

- (id) init
{
    self = [super init];
    gMainController = self;

#if BUILD_ALTIVEC
	_canUseAltivec = CanUseAltivec();
#else
	_canUseAltivec = NO;
#endif
	_numProcessors = CountProcessors();

	_prefs.saveAsJPEG           = YES;
	_prefs.compressTIFF         = YES;
	_prefs.jpegQuality          = 1.0;		// 100% quality
	_prefs.useAltivec           = _canUseAltivec;
	_prefs.useMP                = (_numProcessors > 1);
	_prefs.useLowPriority       = YES;
// 	_prefs.autoStart            = NO;
// 	_prefs.quitWhenDone         = NO;
//	_prefs.useAutoStartTimer    = NO;
	_prefs.autoStartTimerAmount = 1;
	_prefs.autoStartTimerUnits  = hours;
//	_prefs.newOnWakeFromSleep   = NO;
//	_prefs.versionCheckStatus   = @"";
//	_prefs.isCheckingVersion    = NO;

	_patternSize          = sizeCodeRandom;
	_whichPalette         = paletteRandom;
	_whichScreens         = allMonitors;
	_patternPlacement     = tiled;
//	_startMinimized       = NO;
//	_didStartMinimize     = NO;
//  _nextAutoStartTime    = nil;
	_shouldOpenMainWindow = YES;
	_customSize           = NSMakeSize(128.0, 128.0);
	_lastPalettesAdded    = 0;
	_showControlsDrawer   = YES;
	_showRecentDrawer     = YES;

	// This gives better variation on the random seed
	srandom(time(nil));
	_randomSeed           = random();
	_randomSeedOption     = randomSeed;

	// Create the Dock menu
	_dockMenu = [self createDockMenu];

	if ([[self versionDictionary] objectForKey:@"IAmDevelopmentVersion"])
		_versionCheckURL    = [[NSURL URLWithString:@kStarfishXCurrentVersRsrcDev] retain];
	else
		_versionCheckURL    = [[NSURL URLWithString:@kStarfishXCurrentVersRsrc] retain];

	[self loadScreenList];

    return self;
} // init

// -----

- (void) dealloc
{
	[_screenList      release];
	[_paletteList     release];
	[_imageTimer      release];
	[_generator       release];
	[_originalAppIcon release];

	[super dealloc];
} // dealloc

// -----

- (void) abortIfG3WarnIfG4
{
	NSPanel		*alert = nil;

#if BUILD_ALTIVEC
	// This is the Altivec version: if Altivec isn't present, you can't run this
	if (!CanUseAltivec()) {
		alert = NSGetAlertPanel(nil, NSLocalizedString(@"CANT_RUN_G3", @"This version of StarfishX can't be run on a G3 computer."),
									 NSLocalizedString(@"QUIT_BUTTON", @"Quit"), nil, nil);
	} // if
#else
	// This is the non-Altivec version, warn if they have Altivec
	if (CanUseAltivec()) {
		alert = NSGetAlertPanel(nil, NSLocalizedString(@"GET_G4_VERSION", @"This version of StarfishX is not optimized to run on a G4 or higher computer."),
									 NSLocalizedString(@"CONTINUE_BUTTON", @"Continue"), nil, nil);
	} // if
#endif
	if (alert != nil) {
		[NSApp beginSheet:alert modalForWindow:_mainWindow modalDelegate:self didEndSelector:@selector(didEndG3G4Sheet:returnCode:contextInfo:) contextInfo:nil];
		[NSApp runModalForWindow:alert];	// Won't return until dismissed
		[NSApp endSheet:alert];
		[alert orderOut:self];
#if BUILD_ALTIVEC
		_doTerminate = YES;
		[NSApp terminate:nil];
#endif
	} // if
} // abortIfG3WarnIfG4

// -----

- (void) awakeFromNib
{
	// Get reference to our window
	_mainWindow = (MyWindow*) [imageWell window];
	[_mainWindow setDelegate:self];

	[self loadPreferences];			// Must do before exposing window because this loads our window position
    [self initPopups];
    [self setNumRecentText];

	// Set the content area of our drawers to the area of the views they hold
	NSSize		size;
	size = [[controlsDrawer contentView] bounds].size;
	size.height = kControlsDrawerHeight;
	[controlsDrawer setContentSize:size];
	size = [[recentDrawer   contentView] bounds].size;
	[recentDrawer   setContentSize:size];

	// Save a copy of our original application icon
	_originalAppIcon = [[NSApp applicationIconImage] copy];

	// For some reason, this will crash when we call it later
	gVersCheckingString = NSLocalizedString(@"CHECKING_VERS_TEXT", @"Checking…");

	// Set the color picker mask (must do this before instantiating the color picker)
	[NSColorPanel setPickerMask:NSColorPanelAllModesMask];

	[[[recentPictsTable tableColumns] objectAtIndex:0] setDataCell:[[MyThumbnailCell alloc] init]];
	[recentPictsTable setVerticalMotionCanBeginDrag:YES];
	[recentPictsTable setDoubleAction:@selector(tableViewDoubleClick:)];
	[recentPictsTable noteNumberOfRowsChanged];

	// Start looking for lost recent file
	[self findRecentPictures];

	_controlDrawerContentHeight = [controlsDrawer minContentSize].height;
} // awakeFromNib

// -----

- (void) applicationDidBecomeActive:(NSNotification*)aNotification
{
	[self findRecentPictures];			// Rescan for lost recent pictures when we become active
} // applicationDidBecomeActive:

// -----

- (void) applicationDidFinishLaunching:(NSNotification*)aNotification
{
	if (_prefs.useLowPriority)
		setpriority(PRIO_PROCESS, 0, 20);		// Set us to low priority.

	// Setup the controls that work as drag targets
	[randomSeedField setDragTypes:[NSArray arrayWithObjects:kStarfishXInfoPBoardType, NSStringPboardType, nil]];
	[randomSeedField setDragTarget:self];
	[randomSeedField setDragAction:@selector(dragToRandomSeedField:)];
	[patternSizePopup setDragTypes:[NSArray arrayWithObjects:kStarfishXInfoPBoardType, NSStringPboardType, nil]];
	[patternSizePopup setDragTarget:self];
	[patternSizePopup setDragAction:@selector(dragToSizePopup:)];
	[whichPalettePopup setDragTypes:[NSArray arrayWithObjects:kStarfishXInfoPBoardType, NSStringPboardType, nil]];
	[whichPalettePopup setDragTarget:self];
	[whichPalettePopup setDragAction:@selector(dragToPalettePopup:)];

	[self setWindowSizeState];
    [self syncInterface];

	[self abortIfG3WarnIfG4];		// Can't use the Altivec version on a G3, don't want to use the G3 version on a G4

	// Ask the user if it's OK to check for new versions if we haven't
	if (!_askedOKToCheckVersion)
		[self askOKToCheckForNewVersions];

	// Register for system sleep notifications (we really only care about wake from sleep)
    IONotificationPortRef   notify;
    io_object_t             anIterator;

    gRootPort = IORegisterForSystemPower(self, &notify, SystemPowerNotificationCallback, &anIterator);
    if (gRootPort != nil)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notify), kCFRunLoopDefaultMode);

	// Register for our internal notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(patternFinished:) name:kStarfishPatternFinishedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(patternAborted:) name:kStarfishPatternAbortedNotification object:nil];

	// If it's OK to do so, check for a newer version on my website
    if (_prefs.checkVersion)
	    [self checkForNewVersion:kCFBooleanFalse];

	[imageWell setImage:_originalAppIcon];

	// If we're not already generating, do this
	if (_generator == nil) {
		if (_prefs.autoStart)
			[self newPattern:nil];
		else if (_prefs.useAutoStartTimer && _prefs.minimizeWhileWaiting && !_willFireAutoStartTimerSoon && ![_mainWindow isMiniaturized])
			[_mainWindow miniaturize:NSApp];
	} // if	
} // applicationDidFinishLaunching

// -----

- (NSMenu*) applicationDockMenu:(NSApplication*)sender
{
	return _dockMenu;
} // applicationDockMenu

// -----

- (BOOL) applicationShouldHandleReopen:(NSApplication*)theApplication hasVisibleWindows:(BOOL)flag
{
	// It appears that 'flag' will be YES when we have drawers open, even though
	// they're part of the main window which isn't visible.

//	if (!flag) {
		[_mainWindow makeKeyAndOrderFront:self];
//	} // if

	return flag;
} // applicationShouldHandleReopen:hasVisibleWindows:

// -----

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication*)sender
{
	if (!_doTerminate && _generator != nil) {
		_quitSheet = NSGetAlertPanel(nil, NSLocalizedString(@"QUIT_WHILE_GEN_MSG", @"A pattern is currently being generated. Are you sure you want to quit?"),
									 NSLocalizedString(@"QUIT_BUTTON", @"Quit"), NSLocalizedString(@"CONTINUE_BUTTON", @"Continue"), nil);
		[NSApp beginSheet:_quitSheet modalForWindow:_mainWindow modalDelegate:self didEndSelector:@selector(didEndShouldQuitSheet:returnCode:contextInfo:) contextInfo:nil];
		[NSApp runModalForWindow:_quitSheet];	// Won't return until dismissed
// 		NSBeginAlertSheet(nil, NSLocalizedString(@"QUIT_BUTTON", @"Quit"), NSLocalizedString(@"CONTINUE_BUTTON", @"Continue"), nil,
// 						  [sender mainWindow], self, @selector(didEndShouldQuitSheet:returnCode:contextInfo:), nil, nil,
// 						  NSLocalizedString(@"QUIT_WHILE_GEN_MSG", @"A pattern is currently being generated. Are you sure you want to quit?"), nil);
//		return NSTerminateCancel;
		[NSApp endSheet:_quitSheet];
		[_quitSheet orderOut:self];
		_quitSheet = nil;
		if (!_doTerminate)
			return NSTerminateCancel;
	} // if

	// Stop the generators
	if (_generator != nil)
		[_generator stopGenerating];

	// Restore the original app icon in the dock
	[NSApp setApplicationIconImage:_originalAppIcon];

	// We're going to terminate, so save away our preferences
	[self savePreferences];

	return NSTerminateNow;
} // applicationShouldTerminate:

// -----

- (IBAction) changedArrangePopup:(id)sender
{
	_patternPlacement = [placementPopup indexOfSelectedItem];
} // changedArrangePopup:

// -----

- (IBAction) changedMaxRecentPicts:(id)sender
{
	enum maxRecentCodes		newValue = (enum maxRecentCodes) [maxRecentPopup indexOfSelectedItem];
	if (_maxRecentPicts != newValue) {
		NSPanel		*alert = nil;
		NSString	*msg = nil;
		int			count = [self numberOfRecentFiles];

		if ([self numberPicturesToKeep:newValue] < count) {
			// We're going to delete files immediately, make sure the user's OK with that
			count -= [self numberPicturesToKeep:newValue];
			if (count > 1)
				msg = [NSString stringWithFormat:NSLocalizedString(@"TRASH_PATTS_MSG", @"The %d oldest pattern files will be moved to the Trash immediately. Do you wish to proceed?"), count];
			else
				msg = NSLocalizedString(@"TRASH_PATT_MSG", @"The oldest pattern file will be moved to the Trash immediately. Do you wish to proceed?");
			alert = NSGetAlertPanel(nil, msg, NSLocalizedString(@"YES_BUTTON", @"Yes"), NSLocalizedString(@"NO_BUTTON", @"No"), nil);
		} // if

		if (alert != nil) {
			[NSApp beginSheet:alert modalForWindow:_mainWindow modalDelegate:self
				   didEndSelector:@selector(didEndChangedMaxRecentPictsSheet:returnCode:contextInfo:)
				   contextInfo:(void*)newValue];
			[NSApp runModalForWindow:alert];
			// Sheet is up here.
			[NSApp endSheet:alert];
			[alert orderOut:self];
			NSReleaseAlertPanel(alert);
		} else {
			_maxRecentPicts = newValue;
			[self cleanupOldPicts:[self numberPicturesToKeep:_maxRecentPicts]];
		} // if/else
	} // if
} // changedMaxRecentPicts:

// -----

- (IBAction) changedPalettePopup:(id)sender
{
	int		row = _whichPalette;

	_whichPalette = [whichPalettePopup indexOfSelectedItem];
	if (_whichPalette == paletteEdit) {
		// Do the Edit Palettes sheet
		if (_editPalettesController == nil)
			_editPalettesController = [[EditPalettesController alloc] init];
		NSArray		*newPalettes = [_editPalettesController doEditPalettes:_paletteList forWindow:_mainWindow selectRow:row returnRow:&row];
		[self setPaletteList:newPalettes selectRow:row];
		[self savePreferences];
	} // if
} // changedPalettePopup:

// -----
- (IBAction) changedRandomOption:(id)sender
{
	_randomSeedOption = [randomSeedOptionsMatrix selectedRow];
} // changedRandomOption:

// -----

- (IBAction) changedRandomSeed:(id)sender
{
	_randomSeed = [randomSeedField intValue];
} // changedRandomSeed:

// -----

- (IBAction) changedSizePopup:(id)sender
{
	_patternSize = [patternSizePopup indexOfSelectedItem];
	if (_patternSize == sizeCodeCustom) {
		// Do the Custom Size sheet
		if (_customSizeController == nil)
			_customSizeController = [[CustomSizeController alloc] init];
		_customSize = [_customSizeController doCustomSize:_customSize from:self];
		_patternSize = sizeCodeCustom;
		[self savePreferences];
		[self setPopups];
		[self syncInterface];
	} // if
} // changedSizePopup:

// -----

- (IBAction) changedWhichScreenPopup:(id)sender
{
	_whichScreens = [whichScreensPopup indexOfSelectedItem];
} // changedWhichScreenPopup:

// -----

- (IBAction) deletePattern:(id)sender
{
	// This command only works when the "Recent" drawer is showing
    if ([recentDrawer drawerIsOpen]) {
		int		index = [recentPictsTable selectedRow];
		[self deleteRecentPictAtIndex:index moveToTrash:YES];
		[self selectRecentPict:[recentPictsTable selectedRow]];
	} // if
} // deletePattern:

// -----

- (void) drawerDidClose:(NSNotification*)notification
{
	NSDrawer*	drawer = [notification object];
	NSRect		frame = [_mainWindow frame];

	[self syncDrawerArrows];
	if (drawer == recentDrawer) {
		// If we had to move the window to accomodate opening the drawer, move it back now that it's closed
    	if (_wasZoomedWhenDrawerOpen) {
			frame.size.width += [recentDrawer contentSize].width + kDrawerWidthPad;
		} else if (_recentDrawerMovedWindow) {
			// If the window has changed size since we changed it for the drawer, only restore the drawer side to its original location
			if (!NSEqualRects(frame, _recentDrawerOpenWindowFrame)) {
				float	rightEdge = _recentDrawerClosedWindowFrame.size.width + _recentDrawerClosedWindowFrame.origin.x;// Original right edge
				frame.size.width = rightEdge - frame.origin.x;
			} else
				frame = _recentDrawerClosedWindowFrame;
		} // if/else
	} else if (drawer == controlsDrawer) {
		// If we had to move the window to accomodate opening the drawer, move it back now that it's closed
    	if (_wasZoomedWhenDrawerOpen) {
    		float	drawerWidth = [controlsDrawer contentSize].width + kDrawerWidthPad;
			frame.size.width += drawerWidth;
			frame.origin.x -= drawerWidth;
		} else if (_controlsDrawerMovedWindow) {
			// If the window has changed size since we changed it for the drawer, only restore the drawer side to its original location
			if (!NSEqualRects(frame, _controlsDrawerOpenWindowFrame)) {
				float	leftEdge = _controlsDrawerClosedWindowFrame.origin.x;
				frame.size.width += frame.origin.x - leftEdge;
				frame.origin.x = leftEdge;
			} else
				frame = _controlsDrawerClosedWindowFrame;
		} // if/else
	} // if/else

	if (!NSEqualRects(frame, [_mainWindow frame]))
		[_mainWindow setFrame:frame display:YES animate:YES];	// No change, restore everything
} // drawerDidClose:

// -----

- (void) drawerDidOpen:(NSNotification*)notification
{
	[self syncDrawerArrows];
} // drawerDidOpen:

// -----

- (IBAction) doAboutBox:(id)sender
{
	BOOL		didAboutBox = NO;
	// Find the homepage.rtf file in our bundle
	NSString					*path = [[NSBundle mainBundle] pathForResource:@"homepage" ofType:@"rtf"];
	if (path != nil) {
		NSMutableAttributedString	*linkString = [[[NSMutableAttributedString alloc] initWithPath:path documentAttributes:nil] autorelease];
		if (linkString != nil) {
			NSDictionary	*linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[linkString string], NSLinkAttributeName,
													[NSNumber numberWithInt:NSSingleUnderlineStyle], NSUnderlineStyleAttributeName,
													[NSColor blueColor], NSForegroundColorAttributeName, nil];
			[linkString addAttributes:linkAttributes range:NSMakeRange(0, [linkString length])];
			[NSApp orderFrontStandardAboutPanelWithOptions:[NSDictionary dictionaryWithObjectsAndKeys:linkString, @"Credits", nil]];
			didAboutBox = YES;
		} // if
	} // if

	if (!didAboutBox)
		[NSApp orderFrontStandardAboutPanel:self];
} // doAboutBox

// -----

- (IBAction) doCheckVersion:(id)sender
{
	[self checkForNewVersion:kCFBooleanTrue];
} // doCheckVersion:

// -----

- (IBAction) doEditPreferences:(id)sender
{
	BOOL				oldUseTimer             = _prefs.useAutoStartTimer;
	int					oldAutoStartTimerAmount = _prefs.autoStartTimerAmount;
	enum timerCodes		oldAutoStartTimerUnits  = _prefs.autoStartTimerUnits;

	// Do the Preferences sheet
	if (_preferencesController == nil)
		_preferencesController = [[PreferencesController alloc] init];
	[_preferencesController doEditPreferences:&_prefs from:self hasAV:_canUseAltivec hasMP:(_numProcessors > 1)];

	// Start or stop any auto start timer as appropriate (only if we're not generating)
	if (_generator == nil) {
		// Did we turn the timer on or off?
		if (oldUseTimer != _prefs.useAutoStartTimer) {
			if (_prefs.useAutoStartTimer)
				[self installAutoTimer:nil];
			else if (_autoStartTimer != nil) {
				[_autoStartTimer invalidate]; _autoStartTimer = nil;
				[nextStartTimeField setStringValue:@""];			// Clear the "Next pattern at" text
				if (_autoStartStatusItem != nil)
					[_autoStartStatusItem setTitle:@""];
			} // if/else
		} else if (_prefs.useAutoStartTimer && (oldAutoStartTimerAmount != _prefs.autoStartTimerAmount || oldAutoStartTimerUnits != _prefs.autoStartTimerUnits))
			[self installAutoTimer:nil];	// Timer values changed, re-install the timer
	} // if

	[self savePreferences];
} // doEditPreferences:

// -----

- (IBAction) installRecentPatternOnDesktop:(id)sender;
{
	int		scrnIndex = [installPopup indexOfSelectedItem] - 1;	// -1 because first item is always "Install on" item
	int		pictIndex = [recentPictsTable selectedRow];

	[self installOnDesktop:[self recentPathAtIndex:pictIndex] forScreen:[self getScreenByIndex:scrnIndex]];
} // installRecentPatternOnDesktop:

// -----

- (NSWindow*) mainWindow
{
	return _mainWindow;
} // mainWindow

// -----

- (IBAction) newPattern:(id)sender
{
	if (_generator == nil) {
		_continuousGenerate = _optionDown;
		_screenIndex = 0;
		[self createNewPattern];
	} else {
		// This means cancel or skip, depending on the state of the option key
		_skipPattern = _optionDown;
		[_generator stopGenerating];
	} // if/else
} // newPattern:

// -----

- (IBAction) newPatternsUntil:(id)sender
{
	if (_generator == nil) {
		_continuousGenerate = YES;
		_screenIndex = 0;	// This will create full-size patterns for the main monitor if "All monitors" is specified (since we're not installing on a particular monitor)
		[self createNewPattern];
	} else {
		// This means skip the current pattern.
		_skipPattern = YES;
		[_generator stopGenerating];
	} // if/else
} // newPatternUntil:

// -----

- (IBAction) openCloseMainWindow:(id)sender
{
	if (_mainWindowOpen)
		[_mainWindow performClose:self];
	else
		[_mainWindow makeKeyAndOrderFront:self];
} // openCloseMainWindow:

// -----

- (void) patternAborted:(NSNotification*)aNotification
{
	// This means the pattern was aborted
	if (_quitSheet == nil) {
		[self updateImage];				// If the generator didn't finish, clear the image well
		if (_skipPattern) {				// If we're skipping, just start over
			[self createNewPattern];
		} else {
			[self updateNewPatternStatus:YES];
			if (_prefs.useAutoStartTimer)
				[self installAutoTimer:nil];
			_continuousGenerate = NO;
		} // if/else
	} else {
		_doTerminate = YES;
		[NSApp abortModal];
	} // if/else

} // patternAborted:

// -----

- (void) patternFinished:(NSNotification*)aNotification
{
	// This means the pattern finished successfully
	if (_quitSheet != nil) {
		_doTerminate = YES;
		[NSApp abortModal];
	} else {
		if (!_continuousGenerate && _whichScreens == allMonitors && ++_screenIndex < [_screenList count])
			[self createNewPattern];
		else if (_continuousGenerate && [self numberOfRecentFiles] < [self numberPicturesToKeep:_maxRecentPicts]) {
			// If we're continuously generating, make another pattern if our "recent" cache isn't full
			[self createNewPattern];
		} else if (!_prefs.quitWhenDone) {
			_continuousGenerate = NO;
			[self updateNewPatternStatus:YES];
			if (_prefs.useAutoStartTimer) {
				[self installAutoTimer:nil];
				if (_prefs.minimizeWhileWaiting && ![_mainWindow isMiniaturized])
					[_mainWindow miniaturize:NSApp];
			} // if
		} else
			[NSApp terminate:nil];
	} // if/else
} // patternFinished:

// -----

- (IBAction) savePatternAs:(id)sender
{
	int				index = [recentPictsTable selectedRow];

	if (index >= 0 && index < [self numberOfRecentFiles]) {
		NSString		*path = [self recentPathAtIndex:index];
		NSData			*data = [NSData dataWithContentsOfFile:[path stringByExpandingTildeInPath]];
	
		if (data != nil) {
			int				result;
			NSSavePanel		*sp   = [NSSavePanel savePanel];
			static NSString	*lastDirectory = nil;

			/* set up new attributes */
			[sp setRequiredFileType:[path pathExtension]];
			
			/* display the NSSavePanel */
			if (lastDirectory == nil)
				lastDirectory = [NSHomeDirectory() retain];
			result = [sp runModalForDirectory:lastDirectory file:[path lastPathComponent]];
			
			/* if successful, save file under designated name */
			if (result == NSOKButton) {
				[lastDirectory release];
				lastDirectory = [[[sp filename] stringByDeletingLastPathComponent] retain];
				if (![data writeToFile:[sp filename] atomically:YES])
					NSBeep();
			} // if
		} else
			NSBeep();
	} // if
} // savePatternAs:

// -----

- (IBAction) showHideControlsDrawer:(id)sender
{
    if (![controlsDrawer drawerIsOpenOrOpening]) {
    	// Resize window is there's not enough room to open the drawer
    	NSRect	screenFrame = [[_mainWindow screen] frame];
    	NSRect	frame = [_mainWindow frame];
    	float	rightDrawerWidth = ([recentDrawer drawerIsOpenOrOpening] ? [recentDrawer contentSize].width + kDrawerWidthPad : 0);
    	float	widthNeeded = [controlsDrawer contentSize].width + kDrawerWidthPad;
    	float	leftSpace  = (frame.origin.x - screenFrame.origin.x);
		float	rightSpace = (screenFrame.origin.x + screenFrame.size.width) - (frame.origin.x + frame.size.width) - rightDrawerWidth;

		// Do we have enough room to open the drawer?
		if (leftSpace < widthNeeded) {
			_controlsDrawerClosedWindowFrame = frame;

			// Just move the window if we have the room
			if (rightSpace < widthNeeded - leftSpace) {
				// Not enough room. Move what we can, then take the rest out of the width
				frame.size.width -= (widthNeeded - rightSpace - leftSpace);
				frame.origin.x += widthNeeded - leftSpace;
			} else
				frame.origin.x += (widthNeeded - leftSpace);	// There's enough room, just move the window

			BOOL	save = _recentDrawerMovedWindow;
			[_mainWindow setFrame:frame display:YES animate:YES];
			_controlsDrawerMovedWindow = YES;		// Record this after moving the window, since moving it resets this
			_recentDrawerMovedWindow = save;
			_controlsDrawerOpenWindowFrame = frame;
		} else
			_controlsDrawerMovedWindow = NO;

        [controlsDrawer openOnEdge:NSMinXEdge];
    } else {
    	_wasZoomedWhenDrawerOpen = [_mainWindow isZoomed];
		[controlsDrawer close];
	} // if/else

	[self syncDrawerArrows];
} // showHideControlsDrawer:

// -----

- (IBAction) showHideRecentDrawer:(id)sender
{
    if (![recentDrawer drawerIsOpenOrOpening]) {
    	// Resize window is there's not enough room to open the drawer
    	NSRect	screenFrame = [[_mainWindow screen] frame];
    	NSRect	frame = [_mainWindow frame];
    	float	leftDrawerWidth = ([controlsDrawer drawerIsOpenOrOpening] ? [controlsDrawer contentSize].width + kDrawerWidthPad : 0);
    	float	widthNeeded = [recentDrawer contentSize].width + kDrawerWidthPad;
    	float	leftSpace  = (frame.origin.x - screenFrame.origin.x - leftDrawerWidth);
		float	rightSpace = (screenFrame.origin.x + screenFrame.size.width) - (frame.origin.x + frame.size.width);

		// Do we have enough room to open the drawer?
		if (rightSpace < widthNeeded) {
			_recentDrawerClosedWindowFrame = frame;

			// Just move the window if we have the room
			if (leftSpace < widthNeeded - rightSpace) {
				// Not enough room. Move what we can, then take the rest out of the width
				frame.origin.x -= leftSpace;
				frame.size.width -= (widthNeeded - rightSpace - leftSpace);
			} else
				frame.origin.x -= (widthNeeded - rightSpace);	// There's enough room, just move the window

			BOOL	save = _controlsDrawerMovedWindow;
			[_mainWindow setFrame:frame display:YES animate:YES];
			_recentDrawerMovedWindow = YES;		// Record this after moving the window, since moving it resets this
			_controlsDrawerMovedWindow = save;
			_recentDrawerOpenWindowFrame = frame;
		} else
			_recentDrawerMovedWindow = NO;

        [recentDrawer openOnEdge:NSMaxXEdge];
    } else {
    	_wasZoomedWhenDrawerOpen = [_mainWindow isZoomed];
		[recentDrawer close];
	} // if/else

	[self syncDrawerArrows];
} // showHideRecentDrawer:

// -----

- (BOOL) validateMenuItem:(NSMenuItem*)menuItem
{
	SEL				action = [menuItem action];
	BOOL			enable = YES;

	if (action == @selector(openCloseMainWindow:)) {
		[menuItem setTitle:(_mainWindowOpen ? NSLocalizedString(@"CLOSE_MAIN_WINDOW_ITEM", @"Close StarfishX window") : NSLocalizedString(@"OPEN_MAIN_WINDOW_ITEM", @"Open StarfishX window"))];
		[menuItem setKeyEquivalent:(_mainWindowOpen ? @"w" : @"o")];
	} else if (action == @selector(newPattern:)) {
		if (_generator == nil) {
			[menuItem setTitle:NSLocalizedString(@"NEW_PATTERN_ITEM", @"Create New Pattern")];
			if ([menuItem menu] != _dockMenu)
				[menuItem setKeyEquivalent:@"n"];
		} else {
			[menuItem setTitle:NSLocalizedString(@"CANCEL_PATTERN_ITEM", @"Stop Pattern Creation")];
			if ([menuItem menu] != _dockMenu)
				[menuItem setKeyEquivalent:@"."];
		} // if/else
	} else if (action == @selector(newPatternsUntil:)) {
		if (_generator == nil) {
			[menuItem setTitle:NSLocalizedString(@"NEW_PATTERN_UNTIL_ITEM", @"Create Until Recent Cache Full")];
			if ([menuItem menu] != _dockMenu)
				[menuItem setKeyEquivalent:@"n"];
			enable = (_generator == nil && [self numberOfRecentFiles] < [self numberPicturesToKeep:_maxRecentPicts]);
		} else {
			[menuItem setTitle:NSLocalizedString(@"SKIP_PATTERN_ITEM", @"Skip Current Pattern")];
			if ([menuItem menu] != _dockMenu)
				[menuItem setKeyEquivalent:@"."];
		} // if/else
		[menuItem setKeyEquivalentModifierMask:(NSAlternateKeyMask | NSCommandKeyMask)];
	} else if (action == @selector(showHideControlsDrawer:)) {
	    if ([controlsDrawer drawerIsOpenOrOpening])
			[menuItem setTitle:NSLocalizedString(@"HIDE_SETTINGS_DRAWER", @"Hide Pattern Settings")];
		else
			[menuItem setTitle:NSLocalizedString(@"SHOW_SETTINGS_DRAWER", @"Show Pattern Settings")];
		enable = _mainWindowOpen;
	} else if (action == @selector(showHideRecentDrawer:)) {
	    if ([recentDrawer drawerIsOpenOrOpening])
			[menuItem setTitle:NSLocalizedString(@"HIDE_RECENT_DRAWER", @"Hide Recent Patterns")];
		else
			[menuItem setTitle:NSLocalizedString(@"SHOW_RECENT_DRAWER", @"Show Recent Patterns")];
		enable = _mainWindowOpen;
	} else if (menuItem == _autoStartStatusItem) {
		enable = false;
	} // if/else
	return enable;
} // validateMenuItem

// -----

- (void) windowDidBecomeMain:(NSNotification*)aNotification
{
	// Remember that our window is open
	if ([aNotification object] == _mainWindow) {
		if (!_mainWindowOpen) {
			// Our window wasn't open before, setup the drawers
			[self setControlDrawerOffsets];
			if (_showControlsDrawer)
			   [controlsDrawer openOnEdge:NSMinXEdge];
			if (_showRecentDrawer)
				[recentDrawer openOnEdge:NSMaxXEdge];
			[self syncDrawerArrows];
		} // if
		_mainWindowOpen = YES;
		[windowMenu update];
	} // if
} // windowDidBecomeMain:

// -----

- (void) windowDidMove:(NSNotification*)aNotification
{
	// Save the position of the main window
	_controlsDrawerMovedWindow = _recentDrawerMovedWindow = NO;
	[self saveWindowPosition];
} // windowDidMove

// -----

- (void) windowDidResize:(NSNotification*)aNotification
{
	// Save the position of the main window
	_recentDrawerMovedWindow = NO;
	[self saveWindowPosition];
	[self setControlDrawerOffsets];
} // windowDidResize

// -----

- (void) windowWillClose:(NSNotification*)aNotification
{
	// Remember that our window is closed
	if ([aNotification object] == _mainWindow) {
		_showControlsDrawer = [controlsDrawer drawerIsOpen];
		_showRecentDrawer   = [recentDrawer   drawerIsOpen];
		_mainWindowOpen = NO;
		[windowMenu update];
	} // if
} // windowWillClose:

// -----

- (void) windowWillMiniaturize:(NSNotification*)aNotification
{
	NSWindow	*window = [aNotification object];

	if (window != nil) {
		NSImage		*image = nil;
		if (_generator != nil) {
			image = [[self getImage] autorelease];
		} else {
			image = [self recentImageAtIndex:[self indexOfSelectedRecentPict]];
		} // if/else

		if (image != nil) {
			image = MakeThumbnailFromImage(image, NSMakeSize(128.0, 128.0), _originalAppIcon);
		} // if
		[window setMiniwindowImage:image];
		[image release];
	} // if
	[NSApp setApplicationIconImage:_originalAppIcon];
} // windowWillMiniaturize

// -----

- (NSRect) windowWillUseStandardFrame:(NSWindow*)sender defaultFrame:(NSRect)defaultFrame
{
	// Subtract the width of any open drawers
	if ([controlsDrawer drawerIsOpenOrOpening]) {
		float		width = [controlsDrawer contentSize].width + kDrawerWidthPad;
		defaultFrame.size.width -= width;
		defaultFrame.origin.x += width;
	} // if
	if ([recentDrawer drawerIsOpenOrOpening])
		defaultFrame.size.width -= [recentDrawer contentSize].width + kDrawerWidthPad;

	return defaultFrame;
} // windowWillUseStandardFrame:defaultFrame:

// -----

- (void) wokeFromSleep
{
	// Start creating a new pattern if we've been told to do so (and we're not already generating something)
	if (_generator == nil) {
		if (_prefs.newOnWakeFromSleep)
			[self newPattern:self];
		else if (_prefs.useAutoStartTimer)
			[self installAutoTimer:_nextAutoStartTime];	// The timer will fire late (by the amount we slept), so update it
	} // if
} // wokeFromSleep

// -----

@end


/////////////////////////////////////////////
// Internal Implementation--Initialization //
/////////////////////////////////////////////

@implementation StarfishController (private_init)
// -----

- (NSMenu*) createDockMenu
{
	NSMenu	*menu = nil;

	menu = [[NSMenu alloc] initWithTitle:@"StarfishX Dock Menu"];
	if (menu != nil) {
		[menu insertItemWithTitle:NSLocalizedString(@"NEW_PATTERN_ITEM", @"Create New Pattern") action:@selector(newPattern:) keyEquivalent:@"" atIndex:0];
		[menu insertItemWithTitle:NSLocalizedString(@"NEW_PATTERN_UNTIL_ITEM", @"Create Until Recent Cache Full") action:@selector(newPatternsUntil:) keyEquivalent:@"" atIndex:0];
		_autoStartStatusItem = [menu insertItemWithTitle:@"" action:nil keyEquivalent:@"" atIndex:0];
	} // if

	return menu;
} // createDockMenu

// -----

- (void) initPopups
{
	int			i, count;

	// This initializes the dynamic popups which won't change while we're running
	[installPopup removeAllItems];
	[installPopup addItemWithTitle:NSLocalizedString(@"INSTALL_ON_TITLE", @"Install on")];
	for (i = [whichScreensPopup numberOfItems] - 1; i >= mainMonitor; i--)
		[whichScreensPopup removeItemAtIndex:i];
	count = [_screenList count];
	NSMenu	*installMenu = [installPopup menu];
	for (i = 0; i < count; i++) {
		NSDictionary	*dict  = [_screenList objectAtIndex:i];
		NSString		*title = [NSString stringWithFormat:@"%d. %@", i+1, [dict objectForKey:@"DisplayName"]];
        [whichScreensPopup addItemWithTitle:title];
        [installMenu addItemWithTitle:title action:@selector(installRecentPatternOnDesktop:) keyEquivalent:[NSString stringWithFormat:@"%d", i+1]];
	} // for
	[installPopup synchronizeTitleAndSelectedItem];

	[self setPopups];		// Finish by setting the stuff that can change while we run.
} // initPopups

// -----

- (void) loadScreenList
{
	NSMutableArray	*tempList = [NSMutableArray arrayWithCapacity:1];
	GDHandle		gd = nil;

	gd = DMGetFirstScreenDevice(true);
	while (gd != nil) {
		DisplayIDType	displayID;
		Str255			name;

		if (DMGetDisplayIDByGDevice(gd, &displayID, false) == noErr) {
			NSMutableDictionary	*dict = [[NSMutableDictionary alloc] init];
			NSNumber			*screenID = [[NSNumber numberWithLong:displayID] retain];
			NSString			*screenName;

			if (DMGetNameByAVID(displayID, kDMSupressNumbersMask, name) != noErr) {
				if ([tempList count] == 0)
					screenName = [NSString stringWithString:NSLocalizedString(@"MAIN_DISPLAY_ITEM", @"Main Display")];
				else
					screenName = [NSString stringWithFormat:NSLocalizedString(@"DISPLAY_NUM_ITEM", @"Display %d"), [tempList count]+1];
			} else
				screenName = [NSString stringWithCString:name+1 length:name[0]];
			[dict setObject:screenName forKey:@"DisplayName"];
			[dict setObject:screenID forKey:@"DisplayID"];
			[tempList addObject:dict];
		} // if
		gd = DMGetNextScreenDevice(gd, true);
	} // while

	_screenList = [[NSArray arrayWithArray:tempList] retain];
//	NSLog(@"_screenList = %@", _screenList);
} // loadScreenList

@end


/////////////////////////////////////////////
// Internal Implementation--User Interface //
/////////////////////////////////////////////

@implementation StarfishController (private_UI)

// -----

- (void) didEndChangedMaxRecentPictsSheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
	[NSApp stopModal];

	if (returnCode == NSAlertDefaultReturn) {
		_maxRecentPicts = (int) contextInfo;

		// Let the cleanup code decide if there's anything to do
		[self cleanupOldPicts:[self numberPicturesToKeep:_maxRecentPicts]];
	} else
		[self syncInterface];
} // didEndChangedMaxRecentPictsSheet:returnCode:contextInfo:

// -----

- (void) didEndG3G4Sheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
	[NSApp stopModal];
} // didEndG3G4Sheet:returnCode:contextInfo:

// -----

- (void) didEndShouldQuitSheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
	[NSApp stopModal];
	if (returnCode == NSAlertDefaultReturn) {
		_doTerminate = YES;
	} // if
} // didEndShouldQuitSheet:returnCode:contextInfo:

// -----

- (void) dragToPalettePopup:(id)sender
{
	NSString	*info = [sender dragStringForType:kStarfishXInfoPBoardType];
	if (info == nil)
		info = [sender dragStringForType:NSStringPboardType];

	if (info != nil) {
		int			len = [info length];
		NSRange		r = [info rangeOfString:NSLocalizedString(@"INFO_PALETTE_FIND", @"Palette: ")];
		if (r.length > 0) {
			r.location += r.length;			// First character of seed value
			r.length = len - r.location;	// Length of rest of string
			info = [info substringWithRange:r];

			// Look for the longest match to all the palette names
			NSString	*tmp;
			int			l, i, index = -1;

			len = 0;
			i = [_paletteList count];
			tmp = NSLocalizedString(@"PALETTE_FULL_SPECTRUM", @"full spectrum");
			do {
				if ([info hasPrefix:tmp]) {
					l = [tmp length];
					if (l > len) {
						len = l;
						index = i;
					} // if
				} // if

				if (--i < 0)
					break;
				tmp = [[_paletteList objectAtIndex:i] objectForKey:@"name"];
			} while (true);

			if (index >= 0) {
				if (index == (int) [_paletteList count])
					_whichPalette = paletteFullSpectrum;
				else
					_whichPalette = index + paletteFirstDynamic;

				// Select this item
   				[whichPalettePopup selectItemAtIndex:_whichPalette];
			} // if
		} // if
	} // if
} // dragToPalettePopup:

// -----

- (void) dragToRandomSeedField:(id)sender
{
	NSString	*info = [sender dragStringForType:kStarfishXInfoPBoardType];
	if (info == nil)
		info = [sender dragStringForType:NSStringPboardType];

	if (info != nil) {
		int			len = [info length];
		NSRange		r = [info rangeOfString:NSLocalizedString(@"INFO_SEED_FIND", @"Seed: ")];
		if (r.length > 0) {
			r.location += r.length;			// First character of seed value
			r.length = len - r.location;	// Length of rest of string
		} else
			r = NSMakeRange(0, len);	// If we don't find "Seed:" just see if we can find a number at the beginning of the string

		UInt32	seed;
		if (UnsignedIntValueFromString([info substringWithRange:r], &seed, nil)) {
			_randomSeed = seed;
			[randomSeedField setIntValue:seed];
		} // if
	} // if
} // dragToRandomSeedField:

// -----

- (void) dragToSizePopup:(id)sender
{
	NSString	*info = [sender dragStringForType:kStarfishXInfoPBoardType];
	if (info == nil)
		info = [sender dragStringForType:NSStringPboardType];

	if (info != nil) {
		int			len = [info length];
		NSRange		r = [info rangeOfString:NSLocalizedString(@"INFO_SIZE_FIND", @"Size: ")];
		if (r.length > 0) {
			r.location += r.length;			// First character of seed value
			r.length = len - r.location;	// Length of rest of string
			UInt32	width, height;
			if (UnsignedIntValueFromString([info substringWithRange:r], &width, &len)) {
				r.location += len;
				r.length -= len;
				NSString	*tmp = NSLocalizedString(@"INFO_SIZE_FIND2", @" x ");
				if ([[info substringWithRange:r] hasPrefix:tmp]) {
					len = [tmp length];
					r.location += len;
					r.length -= len;
					if (UnsignedIntValueFromString([info substringWithRange:r], &height, nil)) {
						// We've got a valid width & height, set a custom size with these
						// But first, see if this is the size of the selected screen (or the main screen if "all")
						int		index = _whichScreens;
						if (index == allMonitors)
							index = 0;
						else
							index -= mainMonitor;
						NSRect	frame = [[self getScreenByIndex:index] frame];
						if (NSWidth(frame) != width || NSHeight(frame) != height) {
							_patternSize = sizeCodeCustom;
							_customSize.width  = width;
							_customSize.height = height;
							[self setPopups];
						} else
							_patternSize = sizeCodeFullScreen;

					    [patternSizePopup selectItemAtIndex:_patternSize];
					} // if
				} // if
			} // if
		} // if
	} // if
} // dragToSizePopup:

// -----

- (NSString*) localizedDateString:(NSDate*)date
{
	// Create a short date that uses the user prefs
	NSString	*format;

	format = [NSString stringWithFormat:@"%@ %@", [[NSUserDefaults standardUserDefaults] stringForKey: NSShortDateFormatString], [[NSUserDefaults standardUserDefaults] stringForKey: NSTimeFormatString]];
	// add in AM/PM designator if needed
	if ([format rangeOfString:@"H"].location == NSNotFound)
		format = [format stringByAppendingString:@"%p"];
	return [date descriptionWithCalendarFormat:format timeZone:nil locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
} // localizedDateString

// -----

- (void) setControlDrawerOffsets
{
//	int		empty = [_mainWindow frame].size.height - (_controlDrawerContentHeight + kControlsDrawerFudge);

//	[controlsDrawer setLeadingOffset:empty];
} // setControlDrawerOffsets

// -----

- (void) setPaletteList:(NSArray*)newList selectRow:(int)row
{
	if (newList != _paletteList) {
		[_paletteList release];
		_paletteList = [newList retain];
		if (row >= 0 && row < (int) [_paletteList count])
			_whichPalette = row + paletteFirstDynamic;
		else
			_whichPalette = paletteFullSpectrum;		// Reset to full spectrum item because we know it will always be there
		[self setPopups];							// Update the Palettes popup to reflect the changes
		[self syncInterface];						// Make the interface match our internal state
	} // if
} // setPaletteList

// -----

- (void) setPopups
{
    int		i, count;

	// Remove all dynamic items first
	for (i = [whichPalettePopup numberOfItems] - 1; i >= paletteFirstDynamic; i--)
		[whichPalettePopup removeItemAtIndex:i];
	count = [_paletteList count];
    for (i = 0; i < count; i++)
        [whichPalettePopup addItemWithTitle:[[_paletteList objectAtIndex:i] objectForKey:@"name"]];

	// Set the custom size menu item
	[customSizeItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"CUSTOM_SIZE_ITEM", @"Custom (%d x %d)…"), (int) _customSize.width, (int) _customSize.height]];
} // setPopups

// -----

- (void) syncDrawerArrows
{
	// We no longer have different icons for open and closed
} // syncDrawerArrows

// -----

- (void) syncInterface
{
	// Always verify our parameters are valid (can be invalid if certain things change since we last launched)
	if (_whichPalette < 0 || _whichPalette >= [whichPalettePopup numberOfItems])
		_whichPalette = paletteRandom;
	if (_whichScreens < 0 || _whichScreens >= [whichScreensPopup numberOfItems])
		_whichScreens = allMonitors;
	if (_patternSize < 0  || _patternSize  >= [patternSizePopup numberOfItems])
		_patternSize = sizeCodeRandom;
	if (_patternPlacement < 0 || _patternPlacement >= [placementPopup numberOfItems])
		_patternPlacement = tiled;

    [randomSeedField            setIntValue:_randomSeed];
    [whichPalettePopup          selectItemAtIndex:_whichPalette];
    [whichScreensPopup          selectItemAtIndex:_whichScreens];
    [patternSizePopup           selectItemAtIndex:_patternSize];
    [placementPopup             selectItemAtIndex:_patternPlacement];
    [maxRecentPopup				selectItemAtIndex:_maxRecentPicts];
    [randomSeedOptionsMatrix	selectCellAtRow:_randomSeedOption column:0];

    [self syncDrawerArrows];
} // syncInterface

// -----

- (void) toggleNewPatternButton:(NSEvent*)event
{
	_optionDown = (([event modifierFlags] & NSAlternateKeyMask) != 0);
	[self updateNewPatternStatus:(_generator == nil)];
} // toggleNewPatternButton

// -----

- (void) updateNewPatternStatus:(BOOL)doNewPattern
{
	if (doNewPattern) {
		[newPatternButton setTitle:(_optionDown ? NSLocalizedString(@"CONTINUOUS_BUTTON", @"Continuous") : NSLocalizedString(@"NEW_PATTERN_BUTTON", @"New Pattern"))];
		if (!_prefs.useAutoStartTimer)
			[nextStartTimeField setStringValue:@""];
	} else {
		[nextStartTimeField setStringValue:(_continuousGenerate ? NSLocalizedString(@"CONT_PATTERN_TEXT", @"<Continuous Pattern Creation>") : @"")];			// Clear the "Next pattern at" text
		if (_autoStartStatusItem != nil)
			[_autoStartStatusItem setTitle:@""];
		[newPatternButton setTitle:(_optionDown ? NSLocalizedString(@"SKIP_BUTTON", @"Skip Pattern") : NSLocalizedString(@"STOP_BUTTON", @"Stop"))];
	} // if/else
	[patternMenu update];
} // updateNewPatternStatus


@end

// -----

static BOOL CanUseAltivec(void)
{
	OSErr	err;
	long	processorAttributes;
	BOOL	hasAltiVec = NO;

	err = Gestalt(gestaltPowerPCProcessorFeatures, &processorAttributes);

	if (err == noErr)
		hasAltiVec = ((processorAttributes & (1 << gestaltPowerPCHasVectorInstructions)) ? YES : NO);

	return hasAltiVec;
} // CanUseAltivec

// -----

static int CountProcessors(void)
{
	int	count = 1;

	// Must have the MP library and more than one processor
	if (MPLibraryIsLoaded())
		count = MPProcessorsScheduled();
	if (count < 1)
		count = 1;
	return count;
} // CountProcessors

// -----

static BOOL UnsignedIntValueFromString(NSString *str, UInt32 *value, int *len)
{
	NSScanner	*scanner = [NSScanner scannerWithString:str];
	NSString	*numStr;
	BOOL		success;

	// Scan only the numeric characters from the string
	success = [scanner scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&numStr];
	if (success) {
		double		dv;
		scanner = [NSScanner scannerWithString:numStr];
		success = [scanner scanDouble:&dv];
		if (success) {
			*value = (UInt32) dv;
			if (len != nil)
				*len = [numStr length];
		} // if
	} // if

	return success;
} // UnsignedIntValueFromString

// -----

static void SystemPowerNotificationCallback(void *x, io_service_t y, natural_t messageType, void *messageArgument)
{
	id	controller = x;

//	printf("messageType %08lx, arg %08lx\n", (long unsigned int) messageType, (long unsigned int) messageArgument);

	if (messageType == kIOMessageSystemHasPoweredOn)
		[controller wokeFromSleep];

	if (messageType == kIOMessageSystemWillSleep || messageType == kIOMessageCanSystemSleep)
		IOAllowPowerChange(gRootPort, (long) messageArgument);
} // SystemPowerNotificationCallback

// -----
