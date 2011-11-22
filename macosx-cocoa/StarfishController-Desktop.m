#import "StarfishController.h"
#import "StarfishControllerPrivate.h"


static NSString *desktopPrefsPath						= @"~/Library/Preferences/com.apple.desktop.plist";
static NSString *kDesktopNotificationName				= @"com.apple.desktop";
static NSString *kBackgroundChangedNotificationObject	= @"BackgroundChanged";

static NSString *kDesktopBackgroundName					= @"Background";
static NSString *kDesktopDisplayIDName					= @"DisplayID";
static NSString *kDesktopPlacementName					= @"Placement";
static NSString *kDesktopPlacementKeyTagName			= @"PlacementKeyTag";
static NSString *kDesktopImageFilePathName				= @"ImageFilePath";
static NSString *kDesktopPlacementFillScreen			= @"Crop";
static NSString *kDesktopPlacementStretchFill			= @"FillScreen";
static NSString *kDesktopPlacementCenter				= @"Centered";
static NSString *kDesktopPlacementTiled					= @"Tiled";

// -----

static NSNumber* GetDisplayIDFromScreen(NSScreen *screen)
{
	NSDictionary	*dict = [screen deviceDescription];
	NSNumber		*screenID = nil;

	if (dict != nil)
		screenID = [dict objectForKey:@"NSScreenNumber"];

	return screenID;
} // GetDisplayIDFromScreen


/////////////////////////////////////////////////
// Internal Implementation--Desktop Management //
/////////////////////////////////////////////////

@implementation StarfishController (private_desktop)

// -----

- (NSString*) getPlacementString:(enum placementCodes) code;
{
	NSString	*result = kDesktopPlacementTiled;
	switch (code) {
	case fillScreen:
		result = kDesktopPlacementFillScreen; break;
	case stretchToFill:
		result = kDesktopPlacementStretchFill; break;
	case center:
		result = kDesktopPlacementCenter; break;
	case tiled:
	case tiledNotSeamless:
	default:
		result = kDesktopPlacementTiled; break;
	} // switch

	return result;
} // getPlacementString

// -----

- (void) installOnDesktop:(NSString*)path forScreen:(NSScreen*)screen
{
	NSString	*prefsPath;
	NSNumber	*displayID = nil;
	BOOL		setDesktop, changedSomething;

	// Get the screen ID
	displayID = GetDisplayIDFromScreen(screen);
	if (displayID != nil) {
		NSMutableDictionary		*prefsDict, *bgDict, *screenDict;

		// Install it as the desktop picture
		setDesktop = changedSomething = NO;
		prefsPath = [desktopPrefsPath stringByExpandingTildeInPath];
		prefsDict = [NSMutableDictionary dictionaryWithContentsOfFile:prefsPath];
		if (prefsDict == nil) {
			prefsDict = [NSMutableDictionary dictionary];
			changedSomething = YES;
		} // if

		// The stuff we want is in the "Background" dictionary, then the dictionary by screen ID
		bgDict = [prefsDict objectForKey:kDesktopBackgroundName];
		if (bgDict == nil) {
			bgDict = [NSMutableDictionary dictionary];
			changedSomething = YES;
		} // if

		// Get/create the dictionary for this screen
		NSString	*newPlacement = [self getPlacementString:_patternPlacement];
		screenDict = [bgDict objectForKey:[displayID stringValue]];
		if (screenDict == nil) {
			screenDict = [NSMutableDictionary dictionary];
			[screenDict setObject:displayID forKey:kDesktopDisplayIDName];
			changedSomething = YES;
		} else {
			NSString	*oldPath, *oldPlacement;

			// Get the current settings to see if we're actually changing anything
			oldPath      = [screenDict objectForKey:kDesktopImageFilePathName];
			oldPlacement = [screenDict objectForKey:kDesktopPlacementName];
			if (oldPath == nil || oldPlacement == nil || ![oldPath isEqualToString:path] || ![oldPlacement isEqualToString:newPlacement])
				changedSomething = YES;
		} // if/else
		[screenDict setObject:[path stringByExpandingTildeInPath] forKey:kDesktopImageFilePathName];
		if (changedSomething)
			[screenDict setObject:newPlacement forKey:kDesktopPlacementName];
		else	// So something will change
			[screenDict setObject:[self getPlacementString:(_patternPlacement ^ 0x01)] forKey:kDesktopPlacementName];

		// Set the "PlacementKeyTag" so the Desktop prefs pane shows the correct value
		enum placementCodes		placement = _patternPlacement;
		if (placement == tiledNotSeamless)
			placement = tiled;			// Not seamless is for generator use only
		[screenDict setObject:[NSNumber numberWithInt:placement+1] forKey:kDesktopPlacementKeyTagName];

		// Update it in the "Background" dictionary
		[bgDict setObject:screenDict forKey:[displayID stringValue]];
		// Finally, stuff the updated "Background" dictionary into the main prefs dictionary
		[prefsDict setObject:bgDict forKey:kDesktopBackgroundName];
		if ([prefsDict writeToFile:prefsPath atomically:YES])
			setDesktop = YES;
		if (setDesktop) {
			// Tell Finder about it
			CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(),
												 (CFStringRef)kDesktopNotificationName,
												 (void*)kBackgroundChangedNotificationObject, nil, YES);

			// If we didn't change something, we'll need to do this again after Finder's had a chance to update
			_needToSetDesktopAgain = (!changedSomething && !_needToSetDesktopAgain);	// Never do it more than a second time
		} // if
	} // if
} // installOnDesktop:forScreen:

@end

