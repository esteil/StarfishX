#import "StarfishController.h"
#import "StarfishControllerPrivate.h"


#define kRecentFilesCachePath		@"~/Library/Caches/StarfishX Recent Patterns Cache"

static NSString		*oldPrefsPath	= @"~/Library/Preferences/StarfishX.plist";
static NSString		*newPrefsPath	= @"~/Library/Preferences/org.mscott.starfishx.plist";


///////////////////////////////////////
// Internal Implementation--Defaults //
///////////////////////////////////////

static void MigrateOldPrefs(void)
{
	NSString			*oldPath = [oldPrefsPath stringByExpandingTildeInPath];
	NSString			*newPath = [newPrefsPath stringByExpandingTildeInPath];

	if (oldPath != nil && newPath != nil) {
		// See if we have anything in the new location
		NSDictionary		*prefs = [NSDictionary dictionaryWithContentsOfFile:newPath];
		if (prefs == nil) {
			// No, so look for old prefs
			prefs = [NSDictionary dictionaryWithContentsOfFile:oldPath];
			if (prefs != nil) {
				[prefs writeToFile:newPath atomically:YES];
				[[NSUserDefaults standardUserDefaults] synchronize];
			} // if
		} // if
	} // if
} // MigrateOldPrefs


@implementation StarfishController (private_defaults)

// ----

- (void) addAdditionalPalettes
{
	NSMutableArray	*palettes = nil, *theColors;
	NSString		*name;

	// First add-on palette
	if (_lastPalettesAdded < 1) {
		if (palettes == nil)
			palettes = [NSMutableArray arrayWithArray:_paletteList];
		name = NSLocalizedString(@"PALETTE_SKY", @"Sky");
		if (palettes != nil && [self indexOfPaletteNamed:name] < 0) {
			_lastPalettesAdded = 1;
			theColors = [NSArray arrayWithObjects:
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.591], [NSNumber numberWithFloat:0.740], [NSNumber numberWithFloat:0.898], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.714], [NSNumber numberWithFloat:0.746], [NSNumber numberWithFloat:0.820], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.311], [NSNumber numberWithFloat:0.448], [NSNumber numberWithFloat:0.764], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.423], [NSNumber numberWithFloat:0.569], [NSNumber numberWithFloat:0.789], nil],
						nil];
			[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:name, @"name", theColors, @"colors", nil]];
		} // if
	} // if

	// Second add-on palettes
	if (_lastPalettesAdded < 4) {
		if (palettes == nil)
			palettes = [NSMutableArray arrayWithArray:_paletteList];
		name = NSLocalizedString(@"PALETTE_SAVANNAH", @"Savannah");
		if (palettes != nil && [self indexOfPaletteNamed:name] < 0) {
			_lastPalettesAdded = 4;
			theColors = [NSArray arrayWithObjects:
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.995], [NSNumber numberWithFloat:0.812], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.820], [NSNumber numberWithFloat:0.645], [NSNumber numberWithFloat:0.309], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.366], [NSNumber numberWithFloat:0.207], [NSNumber numberWithFloat:0.173], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.111], [NSNumber numberWithFloat:0.120], [NSNumber numberWithFloat:0.248], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.518], [NSNumber numberWithFloat:0.666], [NSNumber numberWithFloat:0.386], nil],
						nil];
			[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:name, @"name", theColors, @"colors", nil]];
		} // if
		name = NSLocalizedString(@"PALETTE_STORM", @"Storm");
		if (palettes != nil && [self indexOfPaletteNamed:name] < 0) {
			_lastPalettesAdded = 4;
			theColors = [NSArray arrayWithObjects:
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.624], [NSNumber numberWithFloat:0.063], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.329], [NSNumber numberWithFloat:0.369], [NSNumber numberWithFloat:0.404], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.502], [NSNumber numberWithFloat:0.635], [NSNumber numberWithFloat:0.773], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.060], [NSNumber numberWithFloat:0.133], [NSNumber numberWithFloat:0.330], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.997], [NSNumber numberWithFloat:0.876], [NSNumber numberWithFloat:0.385], nil],
						nil];
			[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:name, @"name", theColors, @"colors", nil]];
		} // if
		name = NSLocalizedString(@"PALETTE_ATLANTIS", @"Atlantis");
		if (palettes != nil && [self indexOfPaletteNamed:name] < 0) {
			_lastPalettesAdded = 4;
			theColors = [NSArray arrayWithObjects:
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.361], [NSNumber numberWithFloat:0.604], [NSNumber numberWithFloat:0.341], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.106], [NSNumber numberWithFloat:0.122], [NSNumber numberWithFloat:0.286], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.808], [NSNumber numberWithFloat:0.498], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.408], [NSNumber numberWithFloat:0.576], [NSNumber numberWithFloat:0.549], nil],
						[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.365], [NSNumber numberWithFloat:0.420], [NSNumber numberWithFloat:0.565], nil],
						nil];
			[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:name, @"name", theColors, @"colors", nil]];
		} // if
	} // if

	if (palettes != nil) {
		[_paletteList release];
		_paletteList = [[NSArray arrayWithArray:palettes] retain];
	} // if
} // addAdditionalPalettes

// -----

- (void) createDefaultPalettes
{
	NSMutableArray	*palettes, *theColors;

    if (_paletteList != nil)
        [_paletteList release];
    palettes = [[NSMutableArray alloc] init];
    if (palettes == nil) {
        _paletteList = nil;
        return;
    } // if

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.400], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.600], [NSNumber numberWithFloat:0.600], [NSNumber numberWithFloat:1.000], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_BLUE", @"Blue"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.800], [NSNumber numberWithFloat:0.800], [NSNumber numberWithFloat:0.800], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.500], [NSNumber numberWithFloat:0.533], [NSNumber numberWithFloat:0.533], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.267], [NSNumber numberWithFloat:0.267], [NSNumber numberWithFloat:0.267], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_GREY", @"Grey"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.533], [NSNumber numberWithFloat:0.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.125], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.500], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.500], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:1.000], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_RAINBOW", @"Rainbow"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.400], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.600], [NSNumber numberWithFloat:0.600], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_RED", @"Red"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.486], [NSNumber numberWithFloat:0.647], [NSNumber numberWithFloat:0.549], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.455], [NSNumber numberWithFloat:0.616], [NSNumber numberWithFloat:0.584], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.455], [NSNumber numberWithFloat:0.843], [NSNumber numberWithFloat:0.647], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.200], [NSNumber numberWithFloat:0.600], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_SEASIDE", @"Seaside"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.584], [NSNumber numberWithFloat:0.337], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.784], [NSNumber numberWithFloat:0.224], [NSNumber numberWithFloat:0.110], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.875], [NSNumber numberWithFloat:0.322], [NSNumber numberWithFloat:0.208], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.804], [NSNumber numberWithFloat:0.094], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.357], [NSNumber numberWithFloat:0.243], [NSNumber numberWithFloat:0.137], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.118], [NSNumber numberWithFloat:0.239], [NSNumber numberWithFloat:0.094], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.200], [NSNumber numberWithFloat:0.404], [NSNumber numberWithFloat:0.157], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_AUTUMN", @"Autumn"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.235], [NSNumber numberWithFloat:0.184], [NSNumber numberWithFloat:0.192], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.733], [NSNumber numberWithFloat:0.820], [NSNumber numberWithFloat:0.835], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.200], [NSNumber numberWithFloat:0.200], [NSNumber numberWithFloat:0.200], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.078], [NSNumber numberWithFloat:0.082], [NSNumber numberWithFloat:0.184], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.500], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.937], [NSNumber numberWithFloat:0.937], [NSNumber numberWithFloat:0.937], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_WINTER", @"Winter"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.984], [NSNumber numberWithFloat:0.624], [NSNumber numberWithFloat:0.859], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.357], [NSNumber numberWithFloat:0.533], [NSNumber numberWithFloat:0.953], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.753], [NSNumber numberWithFloat:0.957], [NSNumber numberWithFloat:0.227], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.918], [NSNumber numberWithFloat:0.341], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.384], [NSNumber numberWithFloat:0.843], [NSNumber numberWithFloat:0.678], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.361], [NSNumber numberWithFloat:0.753], [NSNumber numberWithFloat:0.302], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.780], [NSNumber numberWithFloat:0.580], [NSNumber numberWithFloat:0.945], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_SPRING", @"Spring"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.624], [NSNumber numberWithFloat:0.220], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.400], [NSNumber numberWithFloat:0.094], [NSNumber numberWithFloat:0.561], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.184], [NSNumber numberWithFloat:0.549], [NSNumber numberWithFloat:0.125], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.918], [NSNumber numberWithFloat:0.341], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.969], [NSNumber numberWithFloat:0.247], [NSNumber numberWithFloat:0.106], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.925], [NSNumber numberWithFloat:0.125], [NSNumber numberWithFloat:0.098], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.271], [NSNumber numberWithFloat:0.110], [NSNumber numberWithFloat:0.831], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.749], [NSNumber numberWithFloat:0.522], [NSNumber numberWithFloat:0.290], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.357], [NSNumber numberWithFloat:0.533], [NSNumber numberWithFloat:0.953], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.859], [NSNumber numberWithFloat:0.271], [NSNumber numberWithFloat:0.420], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_SUMMER", @"Summer"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.388], [NSNumber numberWithFloat:0.635], [NSNumber numberWithFloat:0.898], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.741], [NSNumber numberWithFloat:0.741], [NSNumber numberWithFloat:0.741], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_AQUA", @"Aqua"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.875], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.663], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_USA", @"USA"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.490], [NSNumber numberWithFloat:0.078], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], [NSNumber numberWithFloat:0.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.816], [NSNumber numberWithFloat:0.714], [NSNumber numberWithFloat:0.145], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_HALLOWEEN", @"Halloween"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.110], [NSNumber numberWithFloat:0.235], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.063], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.373], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.871], [NSNumber numberWithFloat:0.871], [NSNumber numberWithFloat:0.871], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_CHRISTMAS", @"Christmas"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.686], [NSNumber numberWithFloat:0.686], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.686], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.686], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.686], [NSNumber numberWithFloat:0.686], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.686], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.686], [NSNumber numberWithFloat:1.000], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:1.000], [NSNumber numberWithFloat:0.686], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_EASTER", @"Easter"), @"name", theColors, @"colors", nil]];

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.890], [NSNumber numberWithFloat:0.310], [NSNumber numberWithFloat:0.020], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.106], [NSNumber numberWithFloat:0.106], [NSNumber numberWithFloat:0.600], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.859], [NSNumber numberWithFloat:0.859], [NSNumber numberWithFloat:0.859], nil],
					nil];
	[palettes addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"PALETTE_BRONCO", @"Bronco"), @"name", theColors, @"colors", nil]];

    _paletteList = [[NSArray arrayWithArray:palettes] retain];
    [palettes release];
	[self addAdditionalPalettes];
} // createDefaultPalettes

// -----

- (int) indexOfPaletteNamed:(NSString*)name
{
	int		i;

	for (i = [_paletteList count] - 1; i >= 0; i--) {
		NSString	*pName = [[_paletteList objectAtIndex:i] objectForKey:@"name"];
		if ([name isEqualToString:pName])
			return i;
	} // for

	return -1;
} // indexOfPaletteNamed:

// -----

- (void) loadPreferences
{
	MigrateOldPrefs();

	NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];

	if ([defaults objectForKey:@"SaveAsJPEG"] != nil)
		_prefs.saveAsJPEG           = [defaults boolForKey:@"SaveAsJPEG"];
	if ([defaults objectForKey:@"CompressTIFF"] != nil)
		_prefs.compressTIFF         = [defaults boolForKey:@"CompressTIFF"];
	if ([defaults objectForKey:@"JPEGQuality"] != nil)
		_prefs.jpegQuality          = [defaults floatForKey:@"JPEGQuality"];
	if (_canUseAltivec && [defaults objectForKey:@"UseAltivec"] != nil)
		_prefs.useAltivec           = [defaults boolForKey:@"UseAltivec"];
	if (_numProcessors > 1 && [defaults objectForKey:@"UseMP"] != nil)
		_prefs.useMP                = [defaults boolForKey:@"UseMP"];
	if ([defaults objectForKey:@"UseLowPriority"] != nil)
		_prefs.useLowPriority       = [defaults boolForKey:@"UseLowPriority"];
	if ([defaults objectForKey:@"CheckForNewerVersion"] != nil)
		_prefs.checkVersion         = [defaults boolForKey:@"CheckForNewerVersion"];
	if ([defaults objectForKey:@"AutoStart"] != nil)
		_prefs.autoStart            = [defaults boolForKey:@"AutoStart"];
	if ([defaults objectForKey:@"QuitWhenDone"] != nil)
		_prefs.quitWhenDone         = [defaults boolForKey:@"QuitWhenDone"];
	if ([defaults objectForKey:@"UseTimer"] != nil)
		_prefs.useAutoStartTimer    = [defaults boolForKey:@"UseTimer"];
	if ([defaults objectForKey:@"TimerAmount"] != nil)
		_prefs.autoStartTimerAmount = [defaults integerForKey:@"TimerAmount"];
	if ([defaults objectForKey:@"TimerUnits"] != nil)
		_prefs.autoStartTimerUnits  = [defaults integerForKey:@"TimerUnits"];
	if ([defaults objectForKey:@"MinimizeWhileWaiting"] != nil)
		_prefs.minimizeWhileWaiting = [defaults boolForKey:@"MinimizeWhileWaiting"];
	if ([defaults objectForKey:@"NewPatternOnWakeFromSleep"] != nil)
		_prefs.newOnWakeFromSleep   = [defaults boolForKey:@"NewPatternOnWakeFromSleep"];

	if ([defaults objectForKey:@"WhichPaletteNew2"] != nil)
		_whichPalette         = [defaults integerForKey:@"WhichPaletteNew2"];
	else if ([defaults objectForKey:@"WhichPaletteNew"] != nil) {
		_whichPalette         = [defaults integerForKey:@"WhichPaletteNew"];
		if (_whichPalette > paletteRandom)
			_whichPalette++;		// To compensate for the "random (no full spectrum) item added with "WhichPaletteNew2"
	} // if
	if ([defaults objectForKey:@"WhichScreens"] != nil)
		_whichScreens         = [defaults integerForKey:@"WhichScreens"];
	if ([defaults objectForKey:@"PatternSize"] != nil)
		_patternSize          = (enum sizeCodes) [defaults integerForKey:@"PatternSize"];
	if ([defaults objectForKey:@"CustomPatternSize.w"] != nil && [defaults objectForKey:@"CustomPatternSize.h"] != nil) {
		_customSize.width     = [defaults integerForKey:@"CustomPatternSize.w"];
		_customSize.height    = [defaults integerForKey:@"CustomPatternSize.h"];
	} // if
	if ([defaults objectForKey:@"PatternPlacement"] != nil)
		_patternPlacement     = (enum placementCodes) [defaults integerForKey:@"PatternPlacement"];
	if ([defaults objectForKey:@"NumberOfRecentStarfishXPatterns"] != nil)
		_maxRecentPicts       = (enum maxRecentCodes) [defaults integerForKey:@"NumberOfRecentStarfishXPatterns"];
	if ([defaults objectForKey:@"OpenAtStart"] != nil)
		_shouldOpenMainWindow = [defaults boolForKey:@"OpenAtStart"];
	if ([defaults objectForKey:@"MinimizeAtStart"] != nil)
		_startMinimized       = [defaults boolForKey:@"MinimizeAtStart"];
	if ([defaults objectForKey:@"RandomSeedOption"] != nil)
		_randomSeedOption     = [defaults integerForKey:@"RandomSeedOption"];
	if ([defaults objectForKey:@"RandomSeedValue"] != nil)
		_randomSeed           = [defaults integerForKey:@"RandomSeedValue"];

	if (_prefs.useAutoStartTimer && [defaults objectForKey:@"NextStartTime"] != nil)
		[self installAutoTimer:[NSDate dateWithString:[defaults stringForKey:@"NextStartTime"]]];

	if ([defaults objectForKey:@"LastVersionCheckTime"] != nil)
		_lastVersionCheckDate = [[NSDate dateWithString:[defaults stringForKey:@"LastVersionCheckTime"]] retain];

	if ([defaults objectForKey:@"StarfishPalettes"] != nil) {
		_paletteList          = [[defaults arrayForKey:@"StarfishPalettes"] retain];
		if ([defaults objectForKey:@"StarfishPalettes_Last_Built-In_Added"] != nil)
			_lastPalettesAdded = [defaults integerForKey:@"StarfishPalettes_Last_Built-In_Added"];
		[self addAdditionalPalettes];
	} else
		[self createDefaultPalettes];	// Load a default set

	if ([defaults objectForKey:@"ShowControlsDrawer"] != nil)
		_showControlsDrawer   = [defaults boolForKey:@"ShowControlsDrawer"];
	if ([defaults objectForKey:@"ShowRecentDrawer"] != nil)
		_showRecentDrawer     = [defaults boolForKey:@"ShowRecentDrawer"];
	if ([defaults objectForKey:@"WindowPosition"] != nil)
		_mainWindowFrame      = [[NSString alloc] initWithString:[defaults stringForKey:@"WindowPosition"]];
	if ([defaults objectForKey:@"AskedOKToCheckNewVersion"] != nil)
		_askedOKToCheckVersion= [defaults boolForKey:@"AskedOKToCheckNewVersion"];

	_recentFilesArray = [[NSUnarchiver unarchiveObjectWithFile:[kRecentFilesCachePath stringByExpandingTildeInPath]] retain];
	if (_recentFilesArray == nil) {
		if ([defaults objectForKey:@"RecentStarfishXPictures"] != nil)
			_recentFilesArray = [[NSMutableArray arrayWithArray:[defaults arrayForKey:@"RecentStarfishXPictures"]] retain];
		else
			_recentFilesArray = [[NSMutableArray alloc] init];
	} // if
} // loadPreferences

// -----

- (void) savePreferences
{
	NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];

	[defaults setBool:_prefs.saveAsJPEG                                 forKey:@"SaveAsJPEG"];
	[defaults setBool:_prefs.compressTIFF                               forKey:@"CompressTIFF"];
	[defaults setFloat:_prefs.jpegQuality								forKey:@"JPEGQuality"];
	if (_canUseAltivec)
		[defaults setBool:_prefs.useAltivec                             forKey:@"UseAltivec"];
	if (_numProcessors > 1)
		[defaults setBool:_prefs.useMP                                  forKey:@"UseMP"];
	[defaults setBool:_prefs.useLowPriority                             forKey:@"UseLowPriority"];
	[defaults setBool:_prefs.checkVersion                               forKey:@"CheckForNewerVersion"];
	[defaults setBool:_prefs.autoStart                                  forKey:@"AutoStart"];
	[defaults setBool:_prefs.quitWhenDone                               forKey:@"QuitWhenDone"];
	[defaults setBool:_prefs.useAutoStartTimer                          forKey:@"UseTimer"];
	[defaults setInteger:_prefs.autoStartTimerAmount                    forKey:@"TimerAmount"];
	[defaults setInteger:_prefs.autoStartTimerUnits                     forKey:@"TimerUnits"];
	[defaults setBool:_prefs.minimizeWhileWaiting                       forKey:@"MinimizeWhileWaiting"];
	[defaults setBool:_prefs.newOnWakeFromSleep                         forKey:@"NewPatternOnWakeFromSleep"];

	[defaults setInteger:_whichPalette                                  forKey:@"WhichPaletteNew2"];
	[defaults setInteger:_whichScreens                                  forKey:@"WhichScreens"];
	[defaults setInteger:_patternSize                                   forKey:@"PatternSize"];
	[defaults setInteger:(int) _customSize.width						forKey:@"CustomPatternSize.w"];
	[defaults setInteger:(int) _customSize.height						forKey:@"CustomPatternSize.h"];
	[defaults setInteger:_patternPlacement                              forKey:@"PatternPlacement"];
	[defaults setInteger:_maxRecentPicts                                forKey:@"NumberOfRecentStarfishXPatterns"];
	[defaults setBool:_mainWindowOpen                                   forKey:@"OpenAtStart"];
	[defaults setBool:(_mainWindowOpen && [_mainWindow isMiniaturized]) forKey:@"MinimizeAtStart"];
	[defaults setInteger:_randomSeedOption                              forKey:@"RandomSeedOption"];
	[defaults setInteger:_randomSeed                                    forKey:@"RandomSeedValue"];
	if (_nextAutoStartTime != nil)
		[defaults setObject:[_nextAutoStartTime description]            forKey:@"NextStartTime"];
	else
		[defaults setObject:@""                                         forKey:@"NextStartTime"];
	if (_lastVersionCheckDate != nil)
		[defaults setObject:[_lastVersionCheckDate description]         forKey:@"LastVersionCheckTime"];
	else
		[defaults setObject:@""                                         forKey:@"LastVersionCheckTime"];

	[defaults setObject:_paletteList                                    forKey:@"StarfishPalettes"];
	[defaults setInteger:_lastPalettesAdded                             forKey:@"StarfishPalettes_Last_Built-In_Added"];
	[defaults setBool:([controlsDrawer state] == NSDrawerOpenState)     forKey:@"ShowControlsDrawer"];
	[defaults setBool:([recentDrawer   state] == NSDrawerOpenState)     forKey:@"ShowRecentDrawer"];
	[defaults setObject:_mainWindowFrame                                forKey:@"WindowPosition"];
	[defaults setBool:_askedOKToCheckVersion                            forKey:@"AskedOKToCheckNewVersion"];
	[defaults setBool:YES				                                forKey:@"AppleDockIconEnabled"];

	// Remove old values
	[defaults setObject:nil                                             forKey:@"WhichPaletteNew"];
	[defaults setObject:nil                                             forKey:@"WhichPalette"];
	[defaults setObject:nil												forKey:@"RecentStarfishXPictures"];

	if (_recentFilesArray != nil)
		[NSArchiver archiveRootObject:_recentFilesArray toFile:[kRecentFilesCachePath stringByExpandingTildeInPath]];

	[defaults synchronize];
} // savePreferences

// -----

- (void) saveWindowPosition
{
	NSString	*frameStr = [_mainWindow stringWithSavedFrame];
	if (frameStr != nil) {
		if (_mainWindowFrame != nil)
			[_mainWindowFrame autorelease];
		_mainWindowFrame = [[NSString alloc] initWithString:frameStr];
	} // if
} // saveWindowPosition

// -----

- (void) setWindowSizeState
{
	if (_mainWindow != nil) {
		// Set the size/state of the main window
		if (_mainWindowFrame != nil && ![_mainWindow isMiniaturized])
			[_mainWindow setFrameFromString:_mainWindowFrame];

		// Show the main window
		if (_shouldOpenMainWindow || _mainWindowOpen) {
			[_mainWindow makeKeyAndOrderFront:self];
			_shouldOpenMainWindow = NO;
			_mainWindowOpen = YES;
		} // if

		// Finally, minimize it, if requested
		if (_mainWindowOpen && _startMinimized && !_didStartMinimize) {
			[_mainWindow miniaturize:NSApp];
			_didStartMinimize = YES;
		} // if
	} // if
} // setWindowSizeState

@end


