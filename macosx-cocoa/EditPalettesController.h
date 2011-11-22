/* EditPalettesController */

#import <Cocoa/Cocoa.h>
#import "MyTableView.h"

@interface EditPalettesController : NSWindowController
{
	NSMutableArray*			_paletteList;
	int						_selectedPalette;
	NSMutableArray*			_componentList;
	BOOL					_componentsChanged;
	NSColorPanel*			_colorPicker;

    IBOutlet NSButton		*addColorButton;
    IBOutlet NSButton		*addPaletteButton;
    IBOutlet NSButton		*doneButton;
    IBOutlet NSButton		*removeColorButton;
    IBOutlet NSButton		*removePaletteButton;
    IBOutlet NSTextField	*colorsText;
    IBOutlet MyTableView	*componentsTable;
    IBOutlet NSTableView	*palettesTable;
}

- (NSArray*) doEditPalettes:(NSArray*)palettes forWindow:(NSWindow*)mainWindow selectRow:(int)initialRow returnRow:(int*)selRow;

- (int) numberOfRowsInTableView:(NSTableView*)aTableView;
- (id) tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex;
- (BOOL) tableView:(NSTableView*)aTableView shouldEditTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex;
- (void) tableView:(NSTableView*)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex;
- (void) tableViewSelectionDidChange:(NSNotification*)aNotification;
- (void) tableView:(NSTableView*)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex;

- (IBAction) addColor:(id)sender;
- (IBAction) addPalette:(id)sender;
- (IBAction) done:(id)sender;
- (IBAction) removeColor:(id)sender;
- (IBAction) removePalette:(id)sender;
@end
