#pragma once

#import "StarfishController.h"


#define kStarfishXInfoPBoardType				@"StarfishInfoPBoardType"
#define kStarfishPatternFinishedNotification	@"StarfishPatternFinishedNotification"
#define kStarfishPatternAbortedNotification		@"StarfishPatternAbortedNotification"


extern StarfishController	*gMainController;

// Various parts of the StarfishController class
@interface StarfishController (private_init)
- (NSMenu*)		createDockMenu;
- (void)		initPopups;
- (void)		loadScreenList;
@end

@interface StarfishController (private_defaults)
- (void)		addAdditionalPalettes;
- (void)		createDefaultPalettes;
- (int)			indexOfPaletteNamed:(NSString*)name;
- (void)		loadPreferences;
- (void)		savePreferences;
- (void)		saveWindowPosition;
- (void)		setWindowSizeState;
@end

@interface StarfishController (private_generation)
- (void)		autoStartTimerFired:(NSTimer*)timer;
- (void)		createNewPattern;
- (NSImage*)	getImage;
- (NSString*)	getImageInfo;
- (NSString*)	getSavePath;
- (NSScreen*)	getScreenByIndex:(int)screenIndex;
- (void)		imageTimerFired:(NSTimer*)timer;
- (void)		installAutoTimer:(NSDate*)when;
- (BOOL)		isGenerating;
- (BOOL)		savePatternToFile:(NSString*)path remember:(BOOL)track;
- (void)		setNewRandomSeed;
- (void)		updateImage;
@end

@interface StarfishController (private_desktop)
- (NSString*)	getPlacementString:(enum placementCodes)code;
- (void)		installOnDesktop:(NSString*)path forScreen:(NSScreen*)screen;
@end

@interface StarfishController (private_recent)
- (void) 		cleanupOldPicts:(int)numToKeep;
- (void)		copy:(id)sender;
- (void)		delete:(id)sender;
- (void)		deleteRecentPictAtIndex:(int)index moveToTrash:(BOOL)trash;
- (void)		findRecentPictures;
- (void)		finishedFindingRecentPictures:(RecentFileFinder*)thread;
- (void)		forgetRecentPictAtIndex:(int)index;
- (int)			indexOfSelectedRecentPict;
- (int)			numberOfRecentFiles;
- (int)			numberPicturesToKeep:(enum maxRecentCodes)code;
- (NSString*)	recentFilenameAtIndex:(int)index;
- (NSImage*)	recentImageAtIndex:(int)index;
- (NSString*)	recentInfoAtIndex:(int)index;
- (NSString*)	recentPathAtIndex:(int)index;
- (NSImage*)	recentThumbnailAtIndex:(int)index;
- (void)		rememberRecentPictPath:(NSString*)path withInfo:(NSString*)info imageData:(NSData*)data;
- (void)		saveRecentFilesArray:(NSUserDefaults*)defaults;
- (void)		selectRecentPict:(int)index;
- (void)		setNumRecentText;
- (void)		setThumbnail:(NSImage*)thumbnail atIndex:(int)index;
- (id)			tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex;
- (void)		tableView:(NSTableView*)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex;
- (void)		tableViewDoubleClick:(id)sender;
- (void)		tableViewSelectionDidChange:(NSNotification*)aNotification;
@end

@interface StarfishController (private_UI)
- (void)		didEndChangedMaxRecentPictsSheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
- (void)		didEndShouldQuitSheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
- (void)		dragToPalettePopup:(id)sender;
- (void)		dragToRandomSeedField:(id)sender;
- (void)		dragToSizePopup:(id)sender;
- (NSString*)	localizedDateString:(NSDate*)date;
- (void)		setControlDrawerOffsets;
- (void)		setPaletteList:(NSArray*)newList selectRow:(int)row;
- (void)		setPopups;
- (void)		syncDrawerArrows;
- (void)		syncInterface;
- (void)		toggleNewPatternButton:(NSEvent*)event;
- (void)		updateNewPatternStatus:(BOOL)doNewPattern;
@end

@interface StarfishController (version_check)
- (void)			askOKToCheckForNewVersions;
- (void)			checkForNewVersion:(CFBooleanRef)force;
- (void)			checkNetworkReachabilityThread:(id)arg;
- (void)			didEndAskCheckVersionSheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
- (void)			didEndFoundNewVersionSheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
- (NSString*)		lastVersionCheckStatus:(NSString*)baseMsg;
- (void)			URL:(NSURL*)sender resourceDidFailLoadingWithReason:(NSString*)reason;
- (void)			URLResourceDidFinishLoading:(NSURL*)sender;
- (NSDictionary*)	versionDictionary;
@end

