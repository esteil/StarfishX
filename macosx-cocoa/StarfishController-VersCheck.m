#import "StarfishController.h"
#import "StarfishControllerPrivate.h"
#import <SystemConfiguration/SystemConfiguration.h>


#define kVersionCheckFrequency		(60*60*24*2)		// Two days (in seconds)
#define kVersionCheckFrequencyDev	(60*60)				// One hour for developement versions


NSString	*gVersCheckingString;
NSString	*gURLString;

const NSString	*kVersionCheckFinished						= @"SFX_VersionCheckFinished";

@interface VersionChecker : NSObject
{
	BOOL				_forceCheck;
} // RecentFileFinder

- (id)		initWithForce:(BOOL)force;

@end

//////////////////////////////////////////////////////
// Internal Implementation--Online version checking //
//////////////////////////////////////////////////////

@implementation StarfishController (version_check)

// -----

- (void) askOKToCheckForNewVersions
{
	NSPanel		*alert;
	alert = NSGetAlertPanel(nil, NSLocalizedString(@"ASK_VERS_CHECK_MSG", @"StarfishX can check its website to see if a newer version is available. (Please see the Read Me file for all the details.) Would you like StarfishX to automatically check for a newer version when it starts up?"),
								 NSLocalizedString(@"YES_CHECK_BUTTON", @"Yes, check"),
								 NSLocalizedString(@"NO_DONT_CHECK_BUTTON", @"No, don't check"), nil);
	if (alert != nil) {
		[NSApp beginSheet:alert modalForWindow:_mainWindow modalDelegate:self didEndSelector:@selector(didEndAskCheckVersionSheet:returnCode:contextInfo:) contextInfo:nil];
		[NSApp runModalForWindow:alert];
		// Sheet is up here.
		[NSApp endSheet:alert];
		[alert orderOut:self];
		NSReleaseAlertPanel(alert);
	} // if
} // askOKToCheckForNewVersions

// -----

- (void) checkForNewVersion:(CFBooleanRef)force
{
	// Nothing to do if we're already checking
	if (_prefs.isCheckingVersion)
		return;

	BOOL						timeToCheck;

	// Only bother with these checks if we're doing an automatic check. If the user clicked the "Check Now" button, then check now, dammit!
	if (!CFBooleanGetValue(force)) {
		id			dev = [[self versionDictionary] objectForKey:@"IAmDevelopmentVersion"];

		// See if it's time to check (we don't want to check too frequently)
		timeToCheck = (_lastVersionCheckDate == nil || [_lastVersionCheckDate timeIntervalSinceNow] < -(dev == nil ? kVersionCheckFrequency : kVersionCheckFrequencyDev));
		if (timeToCheck)
			[NSThread detachNewThreadSelector:@selector(checkNetworkReachabilityThread:) toTarget:self withObject:nil];
		else
			_prefs.versionCheckStatus = [self lastVersionCheckStatus:nil];
	} else {
		[_prefs.versionCheckStatus release];
		_prefs.versionCheckStatus = [gVersCheckingString copy];
		_prefs.isCheckingVersion  = YES;
		if (_versionCheckURL != nil)
			[_versionCheckURL loadResourceDataNotifyingClient:self usingCache:NO];
	} // if/else

	[_preferencesController setVersionCheckStatus];
} // checkForNewVersion

// -----

- (void) checkNetworkReachabilityThread:(id)arg
{
	SCNetworkConnectionFlags	flags;
	BOOL						canAutoCheck;

	// This tells us if we're connected to the Internet or not (we don't want to trigger a connect)
	canAutoCheck = (SCNetworkCheckReachabilityByName(kStarfishXHostName, &flags) && (flags & kSCNetworkFlagsReachable) && !(flags & kSCNetworkFlagsConnectionRequired));
	if (canAutoCheck)
		[self performSelectorOnMainThread:@selector(checkForNewVersion:) withObject:(id)kCFBooleanTrue waitUntilDone:NO]; 
} // checkNetworkReachabilityThread:

// -----

- (void) didEndAskCheckVersionSheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
	_prefs.checkVersion = (returnCode == NSAlertDefaultReturn);
	_askedOKToCheckVersion = YES;
	[NSApp stopModal];
	[self savePreferences];
} // didEndAskCheckVersionSheet:returnCode:contextInfo:

// -----

- (void) didEndFoundNewVersionSheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
	if (returnCode == NSAlertAlternateReturn) {
		NSString					*string     = gURLString;

		if (string == nil) {
			NSString					*path       = [[NSBundle mainBundle] pathForResource:@"homepage" ofType:@"rtf"];
			NSMutableAttributedString	*linkString = [[[NSMutableAttributedString alloc] initWithPath:path documentAttributes:nil] autorelease];

			string     = [linkString string];
		} // if

		if (string == nil)
			string = @"http://homepage.mac.com/mscott/";
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:string]];
	} // if

	[gURLString release]; gURLString = nil;
} // didEndFoundNewVersionSheet:returnCode:contextInfo:

// -----

- (NSString*) lastVersionCheckStatus:(NSString*)baseMsg
{
	id			dev = [[self versionDictionary] objectForKey:@"IAmDevelopmentVersion"];
	NSString	*msg;
	NSString	*lastTime = [self localizedDateString:_lastVersionCheckDate];
	NSString	*nextTime = [self localizedDateString:[_lastVersionCheckDate addTimeInterval:(dev == nil ? kVersionCheckFrequency : kVersionCheckFrequencyDev)]];

	msg = [NSString stringWithFormat:NSLocalizedString(@"CHECK_VERS_DATES", @"Last checked %@\nNext check: %@"), lastTime, nextTime];
	
	if (baseMsg != nil)
		msg = [baseMsg stringByAppendingString:msg];

	return [msg retain];
} // lastVersionCheckStatus

// -----

- (void) URL:(NSURL*)sender resourceDidFailLoadingWithReason:(NSString*)reason
{
	[_prefs.versionCheckStatus release];
	_prefs.versionCheckStatus = [self lastVersionCheckStatus:[NSString stringWithFormat:NSLocalizedString(@"CHECK_VERS_FAILED_TEXT", @"Check failed: %@"), reason]];
	_prefs.isCheckingVersion  = NO;
	[_preferencesController setVersionCheckStatus];
} // URL:resourceDidFailLoadingWithReason:

// -----

- (void) URLResourceDidFinishLoading:(NSURL*)sender
{
	NSPropertyListFormat	fmt = NSPropertyListXMLFormat_v1_0;
	NSString				*err;
	NSString				*msg			= @"Internal Error";
	NSNumber				*myIncrement 	= [[self versionDictionary] objectForKey:@"AutoCheckVersionIncrement"];
//	NSNumber				*myIncrement 	= [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AutoCheckVersionIncrement"];
	NSData					*urlData     	= [sender resourceDataUsingCache:YES];
	id						plist        	= [NSPropertyListSerialization propertyListFromData:urlData mutabilityOption:NSPropertyListImmutable format:&fmt errorDescription:&err];

	if (IsValidCFNumber(myIncrement) && IsValidCFDictionary(plist)) {
		NSDictionary	*dict = (NSDictionary*) plist;

		err = @"Invalid software_versions.plist content";	// Any failure in here probably means I've screwed up the version check file

		// Get the CurrentVersion dictionary
		dict = [dict objectForKey:@"CurrentVersions"];
		if (IsValidCFDictionary(dict)) {
			// Get the StarfishX dictionary
			dict = [dict objectForKey:@"StarfishX"];
			if (IsValidCFDictionary(dict)) {
				NSNumber	*currentIncrement = [dict objectForKey:@"VersionIncrement"];
				if (IsValidCFNumber(currentIncrement)) {
					int		myInc  = [myIncrement intValue];
					int		curInc = [currentIncrement intValue];
					if (myInc < curInc) {
						NSString	*newVersion = [dict objectForKey:@"VersionString"];

						gURLString  = [[dict objectForKey:@"Location"] retain];

						NSWindow	*window = ([_preferencesController editingPrefs] ? [_preferencesController window] : _mainWindow);
						NSBeginAlertSheet(NSLocalizedString(@"NEW_VERS_TITLE", @"New Version!"),
										  NSLocalizedString(@"OK_BUTTON", @"OK"),
										  NSLocalizedString(@"CV_TAKE_ME_THERE", @"Take me there!"),
										  nil, window, self, @selector(didEndFoundNewVersionSheet:returnCode:contextInfo:), nil, nil,
										  NSLocalizedString(@"CV_FOUND_NEW_MSG", @"A newer version (%@) of StarfishX is now available!"), newVersion);

						msg = [NSString stringWithFormat:NSLocalizedString(@"CV_FOUND_NEW_TEXT", @"New version %@ available!"), newVersion];
					} else
						msg = [NSString stringWithFormat:NSLocalizedString(@"CV_CURRENT_VERS_TEXT", @"You have the most recent version of StarfishX.")];
				} // if
			} // if
		} // if
	} else
		msg = [NSString stringWithFormat:NSLocalizedString(@"CHECK_VERS_FAILED_TEXT", @"Check failed: %@"), err];

	// Save time of last successful version check
	[_lastVersionCheckDate release];
	_lastVersionCheckDate = [[NSDate date] retain];

	[_prefs.versionCheckStatus release];
	_prefs.versionCheckStatus = [self lastVersionCheckStatus:msg];
	_prefs.isCheckingVersion  = NO;
	[_preferencesController setVersionCheckStatus];
} // URLResourceDidFinishLoading:

// -----

- (NSDictionary*) versionDictionary
{
	NSString				*versDictPath	= [[NSBundle mainBundle] pathForResource:@"Version" ofType:@"plist"];
	NSDictionary			*infoDict    	= [NSDictionary dictionaryWithContentsOfFile:versDictPath];
	return infoDict;
} // versionDictionary

@end

