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


#import <Cocoa/Cocoa.h>
#import "starfish-engine.h"
#if BUILD_ALTIVEC
	#import "starfish-altivec.h"
#endif
#import "CustomSizeController.h"
#import "EditPalettesController.h"
#import "PreferencesController.h"
#import "MyImageView.h"
#import "MyTableView.h"
#import "MyPopUpButton.h"
#import "MyTextField.h"
#import "MyWindow.h"
#import "SFXUtilities.h"


// This is the name of the host with the SFX version check file
#define kStarfishXHostName			"homepage.mac.com"
// Location of the current versions file
#define kStarfishXCurrentVersRsrc		"http://homepage.mac.com/mscott/software_versions.plist"
#define kStarfishXCurrentVersRsrcDev	"http://homepage.mac.com/mscott/software_versions_dev.plist"


//We don't create patterns any smaller than this value.
#define SMALL_MIN 64
//Medium patterns should be at least this big.
#define MED_MIN 96
//Large patterns must be at least this big.
#define LARGE_MIN 192
//There is no upper limit.

enum magicPalettes
{
	invalidPaletteCode = -1,
    paletteEdit = 0,
    paletteSeparator,
	paletteFullSpectrum,
	paletteRandom,
	paletteRandomNoFullSpectrum,
    paletteSeparator1,
    paletteFirstDynamic
};

enum sizeCodes
{
	invalidSizeCode = -1,
	sizeCodeSmall = 0,
	sizeCodeMedium = 1,
	sizeCodeLarge = 2,
	sizeCodeFullScreen = 3,
	sizeCodeRandom = 4,
	sizeCodeRandomNoFullScreen = 5,
	sizeCodeCustom = 7,
	SIZE_CODE_RANGE = sizeCodeFullScreen,
	SIZE_CODE_RANGE_NO_FULL_SCREEN = sizeCodeLarge
};

enum monitorCodes
{
	invalidMonitorCode = -1,
	allMonitors = 0,
    monitorSeparator = 1,
	mainMonitor = 2
};

enum placementCodes
{
	invalidPlacementCode = -1,
	fillScreen = 0,
	stretchToFill = 1,
	center = 2,
	tiled = 3,
	tiledNotSeamless = 4
};

enum fileFormatCodes
{
    fileFormatTIFF = 0,
    fileFormatJPEG = 1
};

enum maxRecentCodes
{
	recent005 = 0,
	recent010,
	recent025,
	recent050,
	recent100,
	recent250,
	recent500
};

enum randomSeedCodes
{
	sequentialSeed = 0,
	randomSeed,
	constansSeed
};


@class StarfishGenerator;
@class RecentFileFinder;
@class VersionChecker;

@interface StarfishController : NSObject
{
	// These values are saved in our preferences file
	starfishPrefs			_prefs;
	enum sizeCodes			_patternSize;
	BOOL					_startMinimized;
	int						_whichPalette;
	int						_whichScreens;
	enum placementCodes		_patternPlacement;
	enum maxRecentCodes		_maxRecentPicts;
	NSDate*					_nextAutoStartTime;
	NSMutableArray*			_recentFilesArray;
	BOOL					_continuousGenerate;
	BOOL					_shouldOpenMainWindow;
	BOOL					_askedOKToCheckVersion;
	enum randomSeedCodes	_randomSeedOption;
	UInt32					_randomSeed;
	NSSize					_customSize;
	NSString*				_mainWindowFrame;
	int						_lastPalettesAdded;
	BOOL					_showControlsDrawer;
	BOOL					_showRecentDrawer;
	NSDate*					_lastVersionCheckDate;

	// These values are in-memory use only
	BOOL					_canUseAltivec;
	int						_numProcessors;
	BOOL					_mainWindowOpen;
	BOOL					_didStartMinimize;
	BOOL					_willFireAutoStartTimerSoon;
	BOOL					_optionDown;
	BOOL					_skipPattern;
	
	NSArray*				_paletteList;
	NSArray*				_screenList;
	NSDate*					_patternStartTime;

	NSBundle*				_mainBundle;
	NSImage*				_originalAppIcon;
	MyWindow*				_mainWindow;
	id						_quitSheet;
	int						_controlDrawerContentHeight;
	BOOL					_wasZoomedWhenDrawerOpen;
	BOOL					_controlsDrawerMovedWindow;
	NSRect					_controlsDrawerClosedWindowFrame;
	NSRect					_controlsDrawerOpenWindowFrame;
	BOOL					_recentDrawerMovedWindow;
	NSRect					_recentDrawerClosedWindowFrame;
	NSRect					_recentDrawerOpenWindowFrame;

	StarfishGenerator*		_generator;
	UInt32					_generatorSeed;
	unsigned				_screenIndex;
	BOOL					_needToSetDesktopAgain;
	BOOL					_doTerminate;

	RecentFileFinder*		_recentFileFinder;
	VersionChecker*			_versionChecker;
	
	NSTimer*				_imageTimer;
	NSTimer*				_autoStartTimer;
	
	NSMenu*					_dockMenu;
	id <NSMenuItem>			_autoStartStatusItem;
	NSURL*					_versionCheckURL;

	CustomSizeController*	_customSizeController;
	EditPalettesController*	_editPalettesController;
	PreferencesController*	_preferencesController;
	
	// These are the Interface Builder outlets
	IBOutlet MyImageView   			*imageWell;
	IBOutlet NSTextField			*imageInfoText;
	IBOutlet NSButton      			*newPatternButton;
	IBOutlet MyPopUpButton 			*patternSizePopup;
	IBOutlet MyPopUpButton 			*whichPalettePopup;
	IBOutlet NSPopUpButton 			*whichScreensPopup;
	IBOutlet NSPopUpButton 			*placementPopup;
	IBOutlet NSTextField 			*nextStartTimeField;
	IBOutlet NSMatrix				*randomSeedOptionsMatrix;
	IBOutlet MyTextField			*randomSeedField;
	IBOutlet NSPopUpButton 			*maxRecentPopup;
	IBOutlet NSTextField			*numRecentText;
	IBOutlet MyTableView			*recentPictsTable;
	IBOutlet NSButton				*saveAsButton;
	IBOutlet NSPopUpButton			*installPopup;
	IBOutlet NSButton				*deleteButton;
	IBOutlet NSMenu					*windowMenu;
	IBOutlet NSMenuItem				*customSizeItem;
	IBOutlet NSMenu					*patternMenu;
	IBOutlet NSDrawer				*controlsDrawer;
	IBOutlet NSDrawer				*recentDrawer;
	IBOutlet NSButton				*controlsArrowButton;
	IBOutlet NSButton				*recentArrowButton;
}
- (IBAction) changedArrangePopup:(id)sender;
- (IBAction) changedMaxRecentPicts:(id)sender;
- (IBAction) changedPalettePopup:(id)sender;
- (IBAction) changedRandomOption:(id)sender;
- (IBAction) changedRandomSeed:(id)sender;
- (IBAction) changedSizePopup:(id)sender;
- (IBAction) changedWhichScreenPopup:(id)sender;
- (IBAction) deletePattern:(id)sender;
- (IBAction) doAboutBox:(id)sender;
- (IBAction) doCheckVersion:(id)sender;
- (IBAction) doEditPreferences:(id)sender;
- (IBAction) installRecentPatternOnDesktop:(id)sender;
- (IBAction) newPattern:(id)sender;
- (IBAction) newPatternsUntil:(id)sender;
- (IBAction) openCloseMainWindow:(id)sender;
- (IBAction) savePatternAs:(id)sender;
- (IBAction) showHideControlsDrawer:(id)sender;
- (IBAction) showHideRecentDrawer:(id)sender;

- (void)		applicationDidBecomeActive:(NSNotification*)aNotification;
- (void)		applicationDidFinishLaunching:(NSNotification*)aNotification;
- (NSMenu*)		applicationDockMenu:(NSApplication*)sender;
- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication*)sender;
- (void)		patternAborted:(NSNotification*)aNotification;
- (void)		patternFinished:(NSNotification*)aNotification;
- (BOOL)		validateMenuItem:(NSMenuItem*)menuItem;
- (void)		windowDidBecomeMain:(NSNotification*)aNotification;
- (void)		windowDidResize:(NSNotification*)aNotification;
- (void)		windowWillMiniaturize:(NSNotification*)aNotification;
- (NSRect)		windowWillUseStandardFrame:(NSWindow*)sender defaultFrame:(NSRect)defaultFrame;
- (void)		wokeFromSleep;

- (NSWindow*) mainWindow;

@end
