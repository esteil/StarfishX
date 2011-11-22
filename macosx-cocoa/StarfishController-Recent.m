#import "StarfishController.h"
#import "MyTableCells.h"
#import "StarfishControllerPrivate.h"
#import "SFXUtilities.h"

static NSString	*kRecentPatternPathName					= @"path";
static NSString	*kRecentPatternFilename					= @"filename";
static NSString	*kRecentPatternInfo						= @"info";
static NSString	*kRecentPatternThumbnail				= @"thumbnail";

@interface RecentFileFinder : NSObject
{
	NSArray					*_recentFilesArray;		// Copy of the pointer in StarfishController
	NSLock					*_lock;
	int						_count;
	BOOL					*_found;				// Array of the files found
	BOOL					_interrupted;
} // RecentFileFinder

- (id)			initWithRecentArray:(NSArray*)array;
- (void)		findDeadFiles;
- (void)		finishedFindingRecentPictures:(id)sender;
- (BOOL)		finishedOK;
- (BOOL*)		foundArray;
- (void)		recentArrayChanged;

@end

//////////////////////////////////////////////
// Internal Implementation--Recent Patterns //
//////////////////////////////////////////////

@implementation StarfishController (private_recent)

// -----

- (void) cleanupOldPicts:(int)numToKeep
{
	// Make sure we have something to do
	if (_recentFilesArray != nil) {

		int				count = [_recentFilesArray count];

		while (count > numToKeep) {
			// The oldest are last in the array
			count--;	// count is now index of last item in array
			[self deleteRecentPictAtIndex:count moveToTrash:YES];
		} // if

	} // if
} // cleanupOldPicts:

// -----

- (void) copy:(id)sender
{
	int		index = [recentPictsTable selectedRow];

	if (_recentFilesArray != nil && index >= 0 && index < (int) [_recentFilesArray count]) {
		NSImage		*image = [self recentImageAtIndex:index];
		if (image != nil) {
			NSPasteboard	*pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
			[pboard declareTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
			[pboard setData:[image TIFFRepresentation] forType:NSTIFFPboardType];
		} // if
	} else
		SysBeep(1);
} // copy:

// -----

- (void) delete:(id)sender
{
	int		index = [recentPictsTable selectedRow];

	// This command only works when the "Recent" drawer is showing
	if ([recentDrawer state] == NSDrawerOpenState && index >= 0 && index < (int) [_recentFilesArray count]) {
		[self deleteRecentPictAtIndex:index moveToTrash:YES];
		[self selectRecentPict:[recentPictsTable selectedRow]];
	} else
		SysBeep(1);
} // delete:

// -----

- (void) deleteRecentPictAtIndex:(int)index moveToTrash:(BOOL)trash
{
	if (_recentFilesArray != nil && index >= 0 && index < (int) [_recentFilesArray count]) {
		NSFileManager	*mgr  = [NSFileManager defaultManager];
		NSString		*path = [[self recentPathAtIndex:index] stringByExpandingTildeInPath];
		BOOL			isDir;
	
		// Make sure there's a file here and not a directory
		if ([mgr fileExistsAtPath:path isDirectory:&isDir] && !isDir) {
			if (trash) {
				NSArray		*fileArray = [NSArray arrayWithObject:[path lastPathComponent]];
				NSString	*srcDir    = [path stringByDeletingLastPathComponent];
				int			tag;

				// Try moving the file to the trash
				if (![[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:srcDir destination:@"/" files:fileArray tag:&tag])
					SysBeep(1);
			} else
				[mgr removeFileAtPath:path handler:nil];	// Delete it
		} // if
		[self forgetRecentPictAtIndex:index];	// Forget about this item, even if we couldn't delete it
	} // if
} // deleteRecentPictAtIndex:

// -----

- (void) findRecentPictures
{
	if (_recentFileFinder == nil) {
		// Need to have local copy saved before we call init, since it fires the thread and can complete before we even set _recentFilesFinder
		_recentFileFinder = [RecentFileFinder alloc];
		[_recentFileFinder initWithRecentArray:_recentFilesArray];	// Fire and forget (sends a notification when it's done)
	} // if
} // findRecentPictures

// -----

- (void) finishedFindingRecentPictures:(RecentFileFinder*)thread
{
	if (_recentFileFinder == thread) {
		BOOL		finishedOK = [thread finishedOK];
		_recentFileFinder = nil;
		if (finishedOK) {
			BOOL	*found   = [thread foundArray];
			int		i        = [_recentFilesArray count];
			int		sel      = [recentPictsTable selectedRow];
	
			while (--i >= 0) {
				if (!found[i]) {
					[self forgetRecentPictAtIndex:i];
					if (sel > i)
						sel--;
				} // if
			} // while
	
			[self selectRecentPict:sel];
		} // if

		[thread release];
	
		// If our thread got interrupted, try again
		if (!finishedOK)
			[self findRecentPictures];
	} else
		NSLog(@"finishedFindingRecentPictures: called with unknown object (_recentFileFinder = %d, thread = %d", (int) _recentFileFinder, (int) thread);
} // finishedFindingRecentPictures:

// -----

- (void) forgetRecentPictAtIndex:(int)index
{
	if (_recentFilesArray != nil) {
		int		count = [_recentFilesArray count];

		if (index >= 0 && index < count) {
			[_recentFileFinder recentArrayChanged];
			[_recentFilesArray removeObjectAtIndex:index];
			[recentPictsTable reloadData];
			[self setNumRecentText];
		} // if
	} // if
} // forgetRecentPictAtIndex:

// -----

- (int) indexOfSelectedRecentPict
{
	return [recentPictsTable selectedRow];
} // indexOfSelectedRecentPict

// -----

- (int) numberOfRecentFiles
{
	return [_recentFilesArray count];
} // numberOfRecentFiles

// -----

- (int) numberOfRowsInTableView:(NSTableView*)aTableView
{
	if (aTableView == recentPictsTable)
    	return [self numberOfRecentFiles];
   return 0;
} // numberOfRowsInTableView

// -----

- (int) numberPicturesToKeep:(enum maxRecentCodes)code
{
	int		numToKeep = 5;

	switch (code) {
	case recent005:
		numToKeep = 5; break;
	case recent010:
		numToKeep = 10; break;
	case recent025:
		numToKeep = 25; break;
	case recent050:
		numToKeep = 50; break;
	case recent100:
		numToKeep = 100; break;
	case recent250:
		numToKeep = 250; break;
	case recent500:
		numToKeep = 500; break;
	} // switch

	return numToKeep;
} // numberPicturesToKeep:

// -----

- (NSString*) recentFilenameAtIndex:(int)index
{
	NSString	*name = nil;

	if (index >= 0 && index < (int) [_recentFilesArray count])
		name  = [[_recentFilesArray objectAtIndex:index] objectForKey:kRecentPatternFilename];
	return name;
} // recentFilenameAtIndex:

// -----

- (NSImage*) recentImageAtIndex:(int)index
{
	NSImage		*image = nil;

	if (index >= 0 && index < (int) [_recentFilesArray count]) {
		NSString	*path = [self recentPathAtIndex:index];
		if (path != nil) {
			image = [[[NSImage alloc] initWithContentsOfFile:[path stringByExpandingTildeInPath]] autorelease];
			if (image == nil)
				[self findRecentPictures];		// Failed, probably means it's been deleted, so clean up
		} // if
	} // if

	return image;
} // recentImageAtIndex;

// -----

- (NSString*) recentInfoAtIndex:(int)index
{
	NSString	*info = @"";

	if (index >= 0 && index < (int) [_recentFilesArray count])
		info  = [[_recentFilesArray objectAtIndex:index] objectForKey:kRecentPatternInfo];
	return info;
} // recentInfoAtIndex:

// ----

- (NSString*) recentPathAtIndex:(int)index
{
	NSString	*path = nil;

	if (_recentFilesArray != nil && index >= 0 && index < (int) [_recentFilesArray count])
		path = [[_recentFilesArray objectAtIndex:index] objectForKey:kRecentPatternPathName];
	return path;
} // recentPathAtIndex:

// -----

- (NSDictionary*) recentSettingsAtIndex:(int)index
{
	NSDictionary	*dict = nil;

	if (_recentFilesArray != nil && index >= 0 && index < (int) [_recentFilesArray count])
		dict = [[_recentFilesArray objectAtIndex:index] objectForKey:kRecentPatternThumbnail];

	return dict;
} // recentSettingsAtIndex:

// -----

- (NSImage*) recentThumbnailAtIndex:(int)index
{
	NSImage		*thumb = nil;

	if (_recentFilesArray != nil && index >= 0 && index < (int) [_recentFilesArray count])
		thumb = [[_recentFilesArray objectAtIndex:index] objectForKey:kRecentPatternThumbnail];

	return thumb;
} // recentThumbnailAtIndex;

// -----

- (void) rememberRecentPictPath:(NSString*)path withInfo:(NSString*)info imageData:(NSData*)data
{
	[_recentFileFinder recentArrayChanged];

	if (_recentFilesArray != nil) {
		NSImage			*image = [[NSImage alloc] initWithData:data];
		NSImage			*thumb = MakeThumbnailFromImage(image, NSMakeSize(48.0, 48.0), nil);
		[image release];

		// This method will create a dictionary w/o the "thumbnail" key/value pair if thumb == nil
		NSDictionary	*dict = [NSDictionary dictionaryWithObjectsAndKeys:path, kRecentPatternPathName,
																		   info, kRecentPatternInfo,
																		   [path lastPathComponent], kRecentPatternFilename,
																		   thumb, kRecentPatternThumbnail, nil];
		[_recentFilesArray insertObject:dict atIndex:0];
		[recentPictsTable noteNumberOfRowsChanged];
		[self setNumRecentText];
	} // if
} // rememberRecentPictPath:withInfo:imageData:settings

// -----

- (void) saveRecentFilesArray:(NSUserDefaults*)defaults
{
	NSMutableArray		*temp = [[NSMutableArray alloc] init];
	NSEnumerator		*i = [_recentFilesArray objectEnumerator];
	NSDictionary		*dict;

	while ((dict = (NSDictionary*) [i nextObject]) != nil) {
		// Write the dictionary w/o the thumbnail to the temp array
		[temp addObject:[NSDictionary dictionaryWithObjectsAndKeys:[dict objectForKey:kRecentPatternPathName], kRecentPatternPathName,
																   [dict objectForKey:kRecentPatternInfo],     kRecentPatternInfo,
																   [dict objectForKey:kRecentPatternFilename], kRecentPatternFilename, nil]];
	} // while

	// Now save the temp array to defaults
	[defaults setObject:temp forKey:@"RecentStarfishXPictures"];
	[temp release];
} // saveRecentFilesArray

//-----

- (void) selectRecentPict:(int)index
{
	if (index >= 0 && index < (int) [_recentFilesArray count]) {
		[recentPictsTable selectRow:index byExtendingSelection:NO];

		if (_generator == nil) {		// Only update the image well/text if we're not generating
			// Load the image and update the image well with it
			NSImage			*image = [self recentImageAtIndex:index];
			NSString		*info  = [self recentInfoAtIndex:index];

			[imageInfoText    setStringValue:info];
			[imageWell        setImage:image];
			if (_mainWindow != nil && [_mainWindow isMiniaturized]) {
				if (image != nil) {
					image = MakeThumbnailFromImage(image, NSMakeSize(128.0, 128.0), _originalAppIcon);
				} // if
				[_mainWindow setMiniwindowImage:image];
				[image release];
			} // if
		} // if
	} else {
		[recentPictsTable deselectAll:self];
		if (_generator == nil) {
			[imageInfoText    setStringValue:@""];
			[imageWell        setImage:_originalAppIcon];
		} // if
	} // if/else
} // selectRecentPict:

// -----

- (void) setNumRecentText
{
	[numRecentText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"NUM_RECENT_PATT_TEXT", @"(You have %d recent patterns.)"), [_recentFilesArray count]]];
} // setNumRecentText

// -----

- (void) setThumbnail:(NSImage*)thumbnail atIndex:(int)index
{
	if (thumbnail != nil && [self recentThumbnailAtIndex:index] == nil) {
		NSDictionary	*dict = [NSDictionary dictionaryWithObjectsAndKeys:[self recentPathAtIndex:index],     kRecentPatternPathName,
																		   [self recentInfoAtIndex:index],     kRecentPatternInfo,
																		   [self recentFilenameAtIndex:index], kRecentPatternFilename,
																		   thumbnail,                          kRecentPatternThumbnail,
																		   nil];
		if (dict != nil)
			[_recentFilesArray replaceObjectAtIndex:index withObject:dict];
	} // if
} // setThumbnail:atIndex:

// -----

- (id) tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
	if (aTableView == recentPictsTable)
		return [_recentFilesArray objectAtIndex:rowIndex];
	else
		return nil;
} // tableView:objectValueForTableColumn:row:

// -----

- (void) tableView:(NSTableView*)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
	if (aTableView == recentPictsTable) {
		MyThumbnailCell		*cell = (MyThumbnailCell*) aCell;

		// Get the thumbnail for this row
		if (rowIndex < (int) [_recentFilesArray count]) {
			NSImage			*thumb = [self recentThumbnailAtIndex:rowIndex];

			// If we don't already have a thumbnail for this image, load the original image from disk and create a thumbnail
			if (thumb == nil) {
				NSString	*path = [[self recentPathAtIndex:rowIndex] stringByExpandingTildeInPath];
				thumb = MakeThumbnailFromImage([[[NSImage alloc] initWithContentsOfFile:path] autorelease], NSMakeSize(48.0, 48.0), nil);
				// Update the dictionary so we have the thumbnail next time
				if (thumb != nil) {
					[self setThumbnail:thumb atIndex:rowIndex];
				} else
					[self findRecentPictures];		// Failed, probably means it's been deleted, so clean up
			} // if

			[cell setFilename:[self recentFilenameAtIndex:rowIndex] andThumbnail:thumb];
		} // if
	} // if
} // tableView:willDisplayCell:forTableColumn:row:

// -----

- (BOOL) tableView:(NSTableView*)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
	// Write data to the pasteboard
//	NSURL			*fileURL = [NSURL URLWithString:path];
	NSArray			*types = [NSArray arrayWithObjects:NSFilenamesPboardType, kStarfishXInfoPBoardType, nil];
	[pboard declareTypes:types owner:self]; 

	int				count = [rows count];
	NSMutableArray	*files = [NSMutableArray arrayWithCapacity:count];
	while (--count >= 0) {
		int			row      = [[rows objectAtIndex:count] intValue];
		NSString	*path    = [[self recentPathAtIndex:row] stringByExpandingTildeInPath];
		[files addObject:path];
	} // while

//	[fileURL writeToPasteboard:pboard];
	[pboard setPropertyList:files forType:NSFilenamesPboardType];

	// Only write the SFX info if we are dragging one item
	if ([rows count] == 1)
		[pboard setString:[self recentInfoAtIndex:[[rows objectAtIndex:0] intValue]] forType:kStarfishXInfoPBoardType];
	return YES;
} // tableView:writeRows:toPasteboard:

// -----

- (void) tableViewDoubleClick:(id)sender
{
	// Install pattern on the main display
	int		pictIndex = [recentPictsTable selectedRow];

	[self installOnDesktop:[self recentPathAtIndex:pictIndex] forScreen:[self getScreenByIndex:0]];
} // tableViewDoubleClick:

// -----

- (void) tableViewSelectionDidChange:(NSNotification*)aNotification
{
	NSTableView	*table = (NSTableView*) [aNotification object];
	int			index  = [table selectedRow];

	if (table == recentPictsTable)
		[self selectRecentPict:index];
} // tableViewSelectionDidChange:


@end


@implementation RecentFileFinder

- (id) initWithRecentArray:(NSArray*)array
{
	self = [super init];

	if (self != nil) {
		_recentFilesArray = array;
		_lock       = [[NSLock alloc] init];
		_count      = [_recentFilesArray count];
		_found      = calloc(sizeof(BOOL), _count);
		if (_found == nil) {
			[super dealloc];
			self = nil;
		} // if
	} // if

	[NSThread detachNewThreadSelector:@selector(findDeadFiles) toTarget:self withObject:nil];
	return self;
} // initWithRecentArray

// -----

- (void) dealloc
{
	[_lock release];
	free(_found);
	[super dealloc];
} // dealloc

// -----

- (void) findDeadFiles
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSFileManager		*mgr  = [NSFileManager defaultManager];
	int					index = _count;

	while (--index >= 0) {
		NSDictionary	*dict = nil;

		[_lock lock];
		if (!_interrupted) {
			dict = [_recentFilesArray objectAtIndex:index];
			[_lock unlock];
		} else {
			[_lock unlock];
			break;
		} // if/else

		BOOL			isDir;
		NSString		*path = [[dict objectForKey:kRecentPatternPathName] stringByExpandingTildeInPath];
		_found[index] = ([mgr fileExistsAtPath:path isDirectory:&isDir] && !isDir);
	} // while

	[pool release];

	[self performSelectorOnMainThread:@selector(finishedFindingRecentPictures:) withObject:self waitUntilDone:NO]; 
	[NSThread exit];
} // findDeadFiles

// -----

- (void) finishedFindingRecentPictures:(id)sender
{
	[gMainController finishedFindingRecentPictures:self];
} // finishedFindingDeadFiles

// -----

- (BOOL) finishedOK
{
	return !_interrupted;
} // finishedOK

// -----

- (BOOL*) foundArray
{
	return _found;
} // foundArray

// -----

- (void) recentArrayChanged
{
	[_lock lock];
	_interrupted = YES;
	[_lock unlock];
} // recentArrayChanged

// -----

@end
