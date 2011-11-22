#import "StarfishController.h"
#import "StarfishControllerPrivate.h"
#import "StarfishGenerator.h"
#import "SFXUtilities.h"

#define kPeekTimeInterval		(1.0)
#define kProgressTimeInterval	(0.1)

static NSString	*gDesktopPicturePath					= @"~/Library/Desktop Pictures/";
static NSString *gPreferencesPath						= @"~/Library/Preferences/";


///////////////////////////////////////////////
// Internal Implementation--Image Generation //
///////////////////////////////////////////////

@implementation StarfishController (private_generation)

// -----

- (void) autoStartTimerFired:(NSTimer*)timer
{
	[_autoStartTimer invalidate]; _autoStartTimer = nil;
	_willFireAutoStartTimerSoon = NO;
	if (_generator == nil) {
		[imageWell setImage:nil];
		if (_prefs.minimizeWhileWaiting && [_mainWindow isMiniaturized])
			[_mainWindow deminiaturize:NSApp];
		[self newPattern:self];
	} // if
} // autoStartTimerFired

// -----

- (void) createNewPattern
{
	// Determine if we should wrap the edges to create a seemless pattern
	// (Only for non-full-screen patterns when we're in "Tile (seamless)" mode)
	BOOL	wrap = (_patternSize != sizeCodeFullScreen && _patternPlacement == tiled);

	// Seed the random number generator
	_generatorSeed = _randomSeed = [randomSeedField intValue];
	srandom(_generatorSeed);
	random();	// Pull off a random number to try to avoid the repeated palette bug.

	// Determine which screen we're generating for
	if (_whichScreens != allMonitors)
		_screenIndex = _whichScreens - mainMonitor;
	_needToSetDesktopAgain = NO;

	_generator = [[StarfishGenerator alloc]	init:_patternSize
											usePalette:_whichPalette
											paletteArray:_paletteList
											forScreen:[self getScreenByIndex:_screenIndex]
											usingAltivec:_prefs.useAltivec
											numberOfThreads:(_prefs.useMP ? _numProcessors : 1)
											customSize:_customSize
											wrapEdges:wrap];
	if (_generator != nil) {
		// Install the timers we use to update the UI
		_imageTimer       = [NSTimer scheduledTimerWithTimeInterval:kPeekTimeInterval target:self selector:@selector(imageTimerFired:) userInfo:nil repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:_imageTimer forMode:NSModalPanelRunLoopMode];
		_patternStartTime = [[NSDate date] retain];

		// Change the title of "New Pattern" button and Dock menu item
		[self updateNewPatternStatus:NO];

		// Update the image info text
		[imageInfoText    setStringValue:[self getImageInfo]];
		[self updateImage];		// Clear the image 

		// Start generating the image
		[NSThread detachNewThreadSelector:@selector(generateImage) toTarget:_generator withObject:nil];
	} // if
} // createNewPattern

// -----

- (NSImage*) getImage
{
	NSImage		*image = nil;

	if (_generator != nil) {
		NSData	*data;
		data = [_generator imageData:NO];
		if (data != nil) {
			image = [[NSImage alloc] initWithData:data];
			if (image == nil)
				[data release];
		} // if
	} // if

	return image;
} // getImage

// -----

- (NSString*) getImageInfo
{
	NSString	*str = @"-error-";

	if (_generator != nil) {
		NSSize		size         = [_generator patternSize];
		int			paletteIndex = [_generator paletteIndex];
		NSString	*paletteName;
	
		if (paletteIndex >= 0)
			paletteName = [[_paletteList objectAtIndex:paletteIndex] objectForKey:@"name"];
		else
			paletteName = NSLocalizedString(@"PALETTE_FULL_SPECTRUM", @"full spectrum");
		str = [NSString stringWithFormat:NSLocalizedString(@"IMAGE_INFO_LINE", @"Palette: %@, Size: %d x %d, Seed: %d"), paletteName, (int) size.width, (int) size.height, _generatorSeed];
	} // if

	return str;
} // getImageInfo

// -----

- (NSString*) getSavePath
{
	NSFileManager	*mgr = [NSFileManager defaultManager];
	NSString		*path, *baseName;
	BOOL			exists, isDir;

	// See if this target directory exists
	path = [NSString stringWithString:gDesktopPicturePath];
	exists = [mgr fileExistsAtPath:[path stringByExpandingTildeInPath] isDirectory:&isDir];
	if (exists && !isDir) {
		// Try the Preferences folder
		path = [NSString stringWithString:gPreferencesPath];
		exists = [mgr fileExistsAtPath:[path stringByExpandingTildeInPath] isDirectory:&isDir];
		if (exists && !isDir)
			path = @"~/";		// Just use the root of the home directory then
	} // if

	if (!exists && ![mgr createDirectoryAtPath:[path stringByExpandingTildeInPath] attributes:nil])
		return nil;

	NSSize		size         = [_generator patternSize];
	int			paletteIndex = [_generator paletteIndex];
	NSString	*paletteName;

	if (paletteIndex >= 0)
		paletteName = [[_paletteList objectAtIndex:paletteIndex] objectForKey:@"name"];
	else
		paletteName = NSLocalizedString(@"PALETTE_FULL_SPECTRUM", @"full spectrum");
	baseName = [NSString stringWithFormat:NSLocalizedString(@"FILENAME_PREFIX", @"/Starfish-%d-%@-(%dx%d)"), _generatorSeed, paletteName, (int) size.width, (int) size.height];

	NSString	*fullName = baseName;
	int			count = 2;
	do {
		fullName = [fullName stringByAppendingPathExtension:(_prefs.saveAsJPEG ? @"jpg" : @"tiff")];
		fullName = [path stringByAppendingPathComponent:fullName];
		if (![mgr fileExistsAtPath:[fullName stringByExpandingTildeInPath] isDirectory:&isDir])
			break;
		fullName = [NSString stringWithFormat:@"%@-%d", baseName, count++];
	} while(YES);

	return fullName;
} // getSavePath

// -----

- (NSScreen*) getScreenByIndex:(int)screenIndex
{
	NSScreen	*screen = nil;

	if (screenIndex >= 0 && screenIndex < (int) [_screenList count]) {
		NSNumber	*displayID  = [[_screenList objectAtIndex:screenIndex] objectForKey:@"DisplayID"];
		NSArray		*allScreens = [NSScreen screens];
		unsigned	i;
	
		for (i = 0; screen == nil && i < [allScreens count]; i++) {
			NSScreen		*thisScreen = [allScreens objectAtIndex:i];
			NSDictionary	*dict = [thisScreen deviceDescription];
			if (dict != nil) {
				NSNumber	*thisID;
				thisID = [dict objectForKey:@"NSScreenNumber"];
				if ([displayID isEqualToNumber:thisID])
					screen = thisScreen;
			} // if
		} // for
	} // if

	return screen;
} // getScreenByIndex:

// -----

- (void) imageTimerFired:(NSTimer*)timer
{
	if (_generator != nil) {
		[self updateImage];
		if ([_generator done]) {
			BOOL	finished = [_generator imageComplete];

			if (finished) {
				NSString	*path = [self getSavePath];
				if (path != nil) {
					if (_continuousGenerate || !_needToSetDesktopAgain) {			// This is the first time through
						if ([self savePatternToFile:path remember:YES]) {
							if (!_continuousGenerate)	// Don't install on desktop if we're generating continuously
								[self installOnDesktop:path forScreen:[self getScreenByIndex:_screenIndex]];
							[self selectRecentPict:0];	// Select the current pattern in the recent table
							[self savePreferences];
						} // if
					} else
						[self installOnDesktop:path forScreen:[self getScreenByIndex:_screenIndex]];	// Gotta do that weird double-set to make the pattern show
				} // if
			} // if

			if (_continuousGenerate || !_needToSetDesktopAgain) {
				[_generator release];
				_generator = nil;

				[_imageTimer    invalidate]; _imageTimer       = nil;
				[_patternStartTime release]; _patternStartTime = nil;
				[NSApp setApplicationIconImage:_originalAppIcon];

				[self setNewRandomSeed];

				if (finished) {
					[[NSNotificationCenter defaultCenter] postNotificationName:kStarfishPatternFinishedNotification object:self];
				} else {
					[[NSNotificationCenter defaultCenter] postNotificationName:kStarfishPatternAbortedNotification object:self];
				} // if/else
			} // if
		} // if
	} // if
} // imageTimerFired

// -----

- (void) installAutoTimer:(NSDate*)when
{
	NSTimeInterval	interval = 0;

	if (when == nil) {
		// Figure out when our next timer should fire
		switch (_prefs.autoStartTimerUnits) {
		case minutes:
			interval = _prefs.autoStartTimerAmount * 60; break;
		case hours:
			interval = _prefs.autoStartTimerAmount * 60 * 60; break;
		case days:
			interval = _prefs.autoStartTimerAmount * 60 * 60 * 24; break;
		case weeks:
			interval = _prefs.autoStartTimerAmount * 60 * 60 * 24 * 7; break;
		} // switch
	} else
		interval = [when timeIntervalSinceNow];

	// Make sure our new time hasn't already passed
	if (interval <= 1) {
		interval = 2;	// two seconds from now
		_willFireAutoStartTimerSoon = YES;
	} else
		_willFireAutoStartTimerSoon = NO;

	when = [[NSDate alloc] initWithTimeIntervalSinceNow:interval];

	// Install the timer
	[_nextAutoStartTime release];
	_nextAutoStartTime = when;
	if (_autoStartTimer == nil)
		_autoStartTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(autoStartTimerFired:) userInfo:nil repeats:NO];
	else
		[_autoStartTimer setFireDate:when];

	// Update the UI text to reflect the next fire time
	NSString	*dateString = [self localizedDateString:when];
	[nextStartTimeField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"AUTOSTART_TEXT", @"New pattern will automatically be generated:\n%@."), dateString]];
	if (_autoStartStatusItem != nil)
		[_autoStartStatusItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"AUTOSTART_ITEM", @"New pattern at %@"), dateString]];
} // installAutoTimer

// -----

- (BOOL) isGenerating
{
	return (_generator != nil);
} // isGenerating

// -----

- (BOOL) savePatternToFile:(NSString*)path remember:(BOOL)track
{
	NSData		*data;
	BOOL		result = NO;

	// Get the image data
	if (_prefs.saveAsJPEG)
		data = [_generator imageDataAsJPEG:_prefs.jpegQuality];
	else
		data = [_generator imageData:_prefs.compressTIFF];
	if (path != nil && data != nil) {
		// Clean up old pictures (do this before writing new picture to free of disk space)
		[self cleanupOldPicts:[self numberPicturesToKeep:_maxRecentPicts] - 1];	// -1 because we're just about to add this one

		// Write it to a file
		result = [data writeToFile:[path stringByExpandingTildeInPath] atomically:YES];

		if (result && track)
			[self rememberRecentPictPath:path withInfo:[self getImageInfo] imageData:data];
	} // if

	return result;
} // savePatternToFile:remember:

// -----

- (void) setNewRandomSeed
{
	if (_randomSeedOption == randomSeed) {
		srandom(time(nil));
		_randomSeed = random();
	} else if (_randomSeedOption == sequentialSeed)
		_randomSeed++;

	[self syncInterface];
} // setNewRandomSeed

// -----

- (void) updateImage
{
	BOOL		setMain = NO, setMini = NO;
	NSImage		*image = [self getImage];

	// If image is nil, that means we're done generating (probably cancelled)
	if (image == nil) {
		// Just show the currently selected pattern (if any)
		[self selectRecentPict:[recentPictsTable selectedRow]];
		[NSApp setApplicationIconImage:_originalAppIcon];
	} else {
		NSImage		*thumb = MakeThumbnailFromImage(image, NSMakeSize(128.0, 128.0), _originalAppIcon);
	
		if ([_generator done]) {
			setMain = YES;
			setMini = (_mainWindow != nil);
		} else {
			setMini = (_mainWindow != nil && [_mainWindow isMiniaturized]);
			setMain = !setMini;
		} // if/else
	
		if (setMini)
			[_mainWindow setMiniwindowImage:thumb];
		else
			[NSApp setApplicationIconImage:thumb];
	
		if (setMain) {
			[imageWell setImage:image];
		} // if
	
		[thumb release];
	} // if

	[image release];
} // updateImage

@end


