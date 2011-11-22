#import "EditPalettesController.h"
#import "MyTableCells.h"
#import "StarfishController.h"


#define kStarfishXTableViewRowIndexPBoardType		@"StarfishXTableViewRowIndexPBoardType"


// =====

@interface EditPalettesController (private)
- (void)		changeColor:(id)sender;
- (int)			indexOfPaletteNamed:(NSString*)name;
- (void)		saveCurrentPalette;
- (void)		updateUIState;
- (void)		positionColorPicker;
@end

// =====

@implementation EditPalettesController

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
	return @"PaletteEditor";
} // windowNibName

// -----

- (NSArray*) doEditPalettes:(NSArray*)palettes forWindow:(NSWindow*)mainWindow selectRow:(int)initialRow returnRow:(int*)selRow
{
	NSWindow	*window = [self window];

	// Make a copy of the palettes array
	_paletteList    = [NSMutableArray arrayWithArray:palettes];

	// Set the component Table's data cell
	MyColorCell	*colorCell = [[MyColorCell alloc] init];
	[[[componentsTable tableColumns] objectAtIndex:0] setDataCell:colorCell];

	// More NSTableView init
	_selectedPalette = -1;
	[palettesTable   noteNumberOfRowsChanged];
	[palettesTable   deselectAll:self];
	[palettesTable   scrollRowToVisible:0];
	[componentsTable deselectAll:self];
	[componentsTable scrollRowToVisible:0];
	[palettesTable   setVerticalMotionCanBeginDrag:YES];
	[componentsTable setVerticalMotionCanBeginDrag:YES];
    [palettesTable   registerForDraggedTypes:[NSArray arrayWithObjects:kStarfishXTableViewRowIndexPBoardType, nil]];
    [componentsTable registerForDraggedTypes:[NSArray arrayWithObjects:kStarfishXTableViewRowIndexPBoardType, NSColorPboardType, nil]];
	[self updateUIState];

	// Bring up the color picker dialog, too
	[NSColorPanel setPickerMode:NSWheelModeColorPanel];
	_colorPicker = [NSColorPanel sharedColorPanel];
	[_colorPicker setShowsAlpha:NO];
	[_colorPicker setFloatingPanel:YES];
	[_colorPicker setWorksWhenModal:YES];

	[NSApp beginSheet:window modalForWindow:mainWindow modalDelegate:nil didEndSelector:nil contextInfo:nil];
//	[_colorPicker orderFront:self];
	[NSApp orderFrontColorPanel:self];
	[self positionColorPicker];
	if (initialRow >= paletteFirstDynamic) {
		initialRow -= paletteFirstDynamic;
		[palettesTable scrollRowToVisible:initialRow];
		[palettesTable selectRow:initialRow byExtendingSelection:NO];
	} // if
	[NSApp runModalForWindow:window];
	// Sheet is up here.
	[_colorPicker orderOut:self];
	[NSApp endSheet:window];
	[window orderOut:self];

	// Return a non-mutable copy of the palettes array
	*selRow = _selectedPalette;
	return [NSArray arrayWithArray:_paletteList];
} // doEditPalettes:forWindow:

// -----

- (int) numberOfRowsInTableView:(NSTableView*)aTableView
{
	if (aTableView == palettesTable)
    	return [_paletteList count];
    else if (aTableView == componentsTable && _componentList != nil)
    	return [_componentList count];
   return 0;
} // numberOfRowsInTableView

// ----

- (BOOL) tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op
{
    NSPasteboard	*pboard = [info draggingPasteboard];

	if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:kStarfishXTableViewRowIndexPBoardType, nil]] != nil) {
		// This is a move operation
		NSNumber		*index = [pboard propertyListForType:kStarfishXTableViewRowIndexPBoardType];
		NSMutableArray	*array = nil;
		int		srcIdx = [index intValue];
		if (tv == componentsTable) {
			array = _componentList;
		} else if (tv == palettesTable) {
			array = _paletteList;
		} // if/else
		if (array != nil && row != srcIdx) {
			// Get source object;
			id		obj = [array objectAtIndex:srcIdx];
			if (obj != nil) {
				if (srcIdx < row) {
					// Insert it at the destination first (won't change the object at 'srcIdx')
					[array insertObject:obj atIndex:row];
					// Then remove it from its original location
					[array removeObjectAtIndex:srcIdx];
				} else {
					// Remove the source object first (won't change the object at 'row')
					[obj retain];		// Need to retain it before removing it, otherwise it gets released into oblivion
					[array removeObjectAtIndex:srcIdx];
					// Then insert it at its new location
					[array insertObject:obj atIndex:row];
					[obj release];		// Release--we don't need to keep an extra copy
				} // if/else
				[tv reloadData];
				if (array == _componentList)
					_componentsChanged = YES;
			} // if
		} // if
	} // if

	return YES;
} // tableView:acceptDrop:row:dropOperation:

// -----

- (id) tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
	if (aTableView == palettesTable)
		return [[_paletteList objectAtIndex:rowIndex] objectForKey:@"name"];
	else
		return nil;
} // tableView:objectValueForTableColumn:row:

// -----

- (BOOL) tableView:(NSTableView*)aTableView shouldEditTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
	return (aTableView == palettesTable);
} // tableView:shouldEditTableColumn:row:

// -----

- (void) tableView:(NSTableView*)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
	if (aTableView == palettesTable) {
		NSString	*newName = anObject;
		int			existingIdx = [self indexOfPaletteNamed:newName];
		if (rowIndex < (int) [_paletteList count] && [newName length] > 0 && existingIdx < 0) {
			NSArray				*theColors = [[_paletteList objectAtIndex:rowIndex] objectForKey:@"colors"];
			NSDictionary		*dict = [NSDictionary dictionaryWithObjectsAndKeys:newName, @"name", theColors, @"colors", nil];
			[_paletteList replaceObjectAtIndex:rowIndex withObject:dict];
		} else if (existingIdx != rowIndex)		// Don't beep if we didn't change the name of an existing item
			SysBeep(1);
	} // if
} // tableView:setObjectValue:forTableColumn:row:

// -----

- (NSDragOperation) tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
	if ([info draggingSource] == nil || [info draggingSource] != tv)
		return NSDragOperationNone;		// Drag is from outside our app or not the same table as this one. We don't handle those at this time

	if (op == NSTableViewDropOn)
		return NSDragOperationNone;

	return NSDragOperationGeneric;
} // tableView:validateDrop:proposedRow:proposedDropOperation:

// -----

- (void) tableView:(NSTableView*)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
	if (aTableView == componentsTable) {
		MyColorCell		*cell = (MyColorCell*) aCell;

		// Get the color for this row
		if (rowIndex < (int) [_componentList count]) {
			NSArray			*rgb = [_componentList objectAtIndex:rowIndex];
			float			r, g, b;
			r = [[rgb objectAtIndex:0] floatValue];
			g = [[rgb objectAtIndex:1] floatValue];
			b = [[rgb objectAtIndex:2] floatValue];
			[cell setColor:[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0]];
		} // if
	} // if
} // tableView:willDisplayCell:forTableColumn:row:

// -----

- (BOOL) tableView:(NSTableView*)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
	NSArray			*types = nil;
	NSNumber		*index = [rows objectAtIndex:0];

	// Write data to the pasteboard
	if (tableView == componentsTable) {
		types = [NSArray arrayWithObjects:NSColorPboardType, kStarfishXTableViewRowIndexPBoardType, nil];
		[pboard declareTypes:types owner:self]; 
	
		NSArray			*rgb = [_componentList objectAtIndex:[index intValue]];
		float			r, g, b;
		r = [[rgb objectAtIndex:0] floatValue];
		g = [[rgb objectAtIndex:1] floatValue];
		b = [[rgb objectAtIndex:2] floatValue];
		[[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0] writeToPasteboard:pboard];
	
		[pboard setPropertyList:index forType:kStarfishXTableViewRowIndexPBoardType];
	} else if (tableView == palettesTable) {
		types = [NSArray arrayWithObjects:NSStringPboardType, kStarfishXTableViewRowIndexPBoardType, nil];
		[pboard declareTypes:types owner:self]; 
		[pboard setString:[[_paletteList objectAtIndex:[index intValue]] objectForKey:@"name"] forType: NSStringPboardType];
		[pboard setPropertyList:index forType:kStarfishXTableViewRowIndexPBoardType];
	} // if/else

	return YES;
} // tableView:writeRows:toPasteboard:

// -----

- (void) tableViewSelectionDidChange:(NSNotification*)aNotification
{
	NSTableView	*table = (NSTableView*) [aNotification object];

	if (table == palettesTable) {
		int		newPalette = [palettesTable selectedRow];

		// We got a new palette, save the old one (if it's changed)
		if (newPalette != _selectedPalette)
			[self saveCurrentPalette];

		// Load the new palette
		if (newPalette >= 0 && newPalette < (int) [_paletteList count])
			_componentList = [[NSMutableArray arrayWithArray:[[_paletteList objectAtIndex:newPalette] objectForKey:@"colors"]] retain];
		_componentsChanged = NO;
		_selectedPalette = newPalette;
		[componentsTable deselectAll:self];
		[componentsTable scrollRowToVisible:0];
		[componentsTable reloadData];
	} else if (table == componentsTable && _componentList != nil) {
		// Get the selected color
		int		rowIndex = [componentsTable selectedRow];

		if (rowIndex >= 0 && rowIndex < (int) [_componentList count]) {
			NSArray		*entry = [_componentList objectAtIndex:rowIndex];
			NSColor		*color = [NSColor colorWithCalibratedRed:[[entry objectAtIndex:0] floatValue]
														   green:[[entry objectAtIndex:1] floatValue]
														    blue:[[entry objectAtIndex:2] floatValue]
														   alpha:1.0];
			[_colorPicker setColor:color];
		} // if
	} // if/else

	[self updateUIState];
} // tableViewSelectionDidChange:

// -----

- (IBAction) addColor:(id)sender
{
	int			rowIndex;
	NSArray		*newColor = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0.5], [NSNumber numberWithFloat:0.5], [NSNumber numberWithFloat:0.5], nil];

	[_componentList addObject:newColor];
	[componentsTable noteNumberOfRowsChanged];

	rowIndex = [_componentList count]-1;
	[componentsTable selectRow:rowIndex byExtendingSelection:NO];
	_componentsChanged = YES;
	[self updateUIState];
} // addColor:

// -----

- (IBAction) addPalette:(id)sender
{
	NSArray			*theColors;
	NSDictionary	*newDict;
	int				rowIndex;

	theColors = [NSArray arrayWithObjects:
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:1.0], [NSNumber numberWithFloat:1.0], [NSNumber numberWithFloat:1.0], nil],
					[NSArray arrayWithObjects:[NSNumber numberWithFloat:0.0], [NSNumber numberWithFloat:0.0], [NSNumber numberWithFloat:0.0], nil],
					nil];
	newDict = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"UNTITLED_PALETTE", @"untitled palette"), @"name", theColors, @"colors", nil];
	[_paletteList addObject:newDict];
	[palettesTable noteNumberOfRowsChanged];

	rowIndex = [_paletteList count]-1;
	[palettesTable selectRow:rowIndex byExtendingSelection:NO];
	[palettesTable editColumn:0 row:rowIndex withEvent:nil select:YES];
} // addPalette:

// -----

- (IBAction) done:(id)sender
{
	[self saveCurrentPalette];
	[NSApp stopModal];
} // done:

// -----

- (IBAction) removeColor:(id)sender
{
	int			rowIndex = [componentsTable selectedRow];
	int			count = [_componentList count];

	// Make sure we've got more than two colors (each palette must have at least two colors)
	if (count > 2 && rowIndex >= 0 && rowIndex < count) {
		[_componentList removeObjectAtIndex:rowIndex];
		[componentsTable noteNumberOfRowsChanged];
		_componentsChanged = YES;
	} // if

	[self updateUIState];
} // removeColor:

// -----

- (IBAction) removePalette:(id)sender
{
	int			rowIndex = [palettesTable selectedRow];
	if (rowIndex >= 0 && rowIndex < (int) [_paletteList count]) {
		_selectedPalette = -1;		// Don't want to be writing to a deleted palette!
		[_componentList release]; _componentList = nil;
		[_paletteList removeObjectAtIndex:rowIndex];
		[palettesTable noteNumberOfRowsChanged];
		[palettesTable deselectAll:self];
		[componentsTable reloadData];
	} // if
} // removePalette:

// -----

@end

// =====

@implementation EditPalettesController (private)

// -----

- (void) changeColor:(id)sender
{
	if (_componentList != nil) {
		int			row    = [componentsTable selectedRow];

		if (row >= 0 && row < (int) [_componentList count]) {
			NSColor		*color = [[_colorPicker color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
			NSArray		*newColor = [NSArray arrayWithObjects:[NSNumber numberWithFloat:[color redComponent]],
															  [NSNumber numberWithFloat:[color greenComponent]],
															  [NSNumber numberWithFloat:[color blueComponent]],
															  nil];
			if (![[_componentList objectAtIndex:row] isEqualToArray:newColor]) {
				[_componentList replaceObjectAtIndex:row withObject:newColor];
				_componentsChanged = YES;
				[componentsTable reloadData];
			} // if
		} // if
	} // if
} // changeColor

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

- (void) saveCurrentPalette
{
	// Save the (possibly) changed components array
	if (_componentList != nil && _componentsChanged && _selectedPalette >= 0) {
		NSArray		*newColors = [NSArray arrayWithArray:_componentList];
		if (newColors != nil) {
			NSString		*name    = [[_paletteList objectAtIndex:_selectedPalette] objectForKey:@"name"];
			NSDictionary	*newDict = [NSDictionary dictionaryWithObjectsAndKeys:name, @"name", newColors, @"colors", nil];
			if (newDict != nil)
				[_paletteList replaceObjectAtIndex:_selectedPalette withObject:newDict];
		} // if
	} // if

	[_componentList release]; _componentList = nil;
} // saveCurrentPalette

// -----

- (void) updateUIState
{
	// Update the buttons based on the selection
	int		rowIndex = [palettesTable selectedRow];
	BOOL	rowValid = (rowIndex >= 0 && rowIndex < (int) [_paletteList count]);
	[removePaletteButton setEnabled:rowValid];

	// Update the static text
	NSString	*string;
	if (rowValid)
		string = [NSString stringWithFormat:NSLocalizedString(@"COLORS_TABLE_HEADER", @"Colors for Ò%@Ó:"), [[_paletteList objectAtIndex:rowIndex] objectForKey:@"name"]];
	else
		string = @"";
	[colorsText setStringValue:string];

	rowIndex = [componentsTable selectedRow];
	rowValid = (_componentList != nil && rowIndex >= 0 && rowIndex < (int) [_componentList count]);
	[addColorButton		setEnabled:(_componentList != nil)];
	[removeColorButton  setEnabled:(rowValid && [_componentList count] > 2)];	// Must have at last two colors in each palette
} // updateUIState

// -----

- (void) positionColorPicker
{
	// Get the position of our sheet and the color picker
	NSRect		myRect     = [[self window] frame];
	NSRect		pickerRect = [_colorPicker frame];

	if (NSIntersectsRect(myRect, pickerRect)) {
		NSRect	screenRect  = [[[self window] screen] frame];
		float	pickerWidth = NSWidth(pickerRect);
		// The sheer will obscure part of the color picker, let's move the picker
		// Try moving it to the left of the sheet first.
		if (NSMinX(myRect) - pickerWidth >= NSMinX(screenRect))
			pickerRect = NSOffsetRect(pickerRect, NSMinX(myRect) - NSMaxX(pickerRect) - 1, 0);
		else if (NSMaxX(myRect) + pickerWidth <= NSMaxX(screenRect))
			pickerRect = NSOffsetRect(pickerRect, NSMaxX(myRect) - NSMinX(pickerRect) + 1, 0);
		else {
			// Won't completely fit on either side of our sheet, move it to the edge of the screen on the widest side
			if (NSMinX(myRect) - NSMinX(screenRect) > NSMaxX(screenRect) - NSMaxX(myRect))
				pickerRect = NSOffsetRect(pickerRect, NSMinX(pickerRect) - NSMinX(screenRect), 0);	// Move to left edge
			else
				pickerRect = NSOffsetRect(pickerRect, NSMaxX(screenRect) - NSMaxX(pickerRect), 0);	// Move to right edge
		} // if/else

		[_colorPicker setFrame:pickerRect display:NO];
	} // if
} // positionColorPicker

// -----

@end
