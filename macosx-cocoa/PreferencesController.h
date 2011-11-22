/* PreferencesController */

#import <Cocoa/Cocoa.h>


enum timerCodes
{
	minutes = 0,
	hours = 1,
	days = 2,
	weeks = 3
};


@class StarfishController;

typedef struct {
	BOOL				saveAsJPEG;
	BOOL				compressTIFF;
	BOOL				useAltivec;
	BOOL				useMP;
	BOOL				useLowPriority;
	BOOL				checkVersion;
	BOOL				autoStart;
	BOOL				quitWhenDone;
	BOOL				useAutoStartTimer;
	BOOL				minimizeWhileWaiting;
	BOOL				newOnWakeFromSleep;
	int					autoStartTimerAmount;
	enum timerCodes		autoStartTimerUnits;
	float				jpegQuality;

	// These aren't actually preferences, but here because our Prefs sheet needs them
	// and the main app needs to store these before this sheet might exist
	NSString*			versionCheckStatus;
	BOOL				isCheckingVersion;
} starfishPrefs;


@interface PreferencesController : NSWindowController
{
	starfishPrefs				*_prefs;
	StarfishController			*_mainController;
	BOOL						_canUseAltivec;
	BOOL						_canUseMP;
	BOOL						_editingPrefs;

	IBOutlet NSPopUpButton 			*fileFormatPopup;
	IBOutlet NSSlider				*jpegQualitySlider;
	IBOutlet NSTextField			*qualityStaticText;
	IBOutlet NSTextField			*sliderScaleStaticText;
	IBOutlet NSButton      			*useMPSwitch;
	IBOutlet NSButton      			*useAltivecSwitch;
	IBOutlet NSButton				*lowPrioritySwitch;

	IBOutlet NSButton				*autoStartSwitch;
	IBOutlet NSButton				*newOnWakeFromSleepSwitch;
	IBOutlet NSButton				*quitWhenDoneSwitch;

	IBOutlet NSButton				*useTimerSwitch;
	IBOutlet NSTextField			*everyStaticText;
	IBOutlet NSPopUpButton			*timerUnitPopup;
	IBOutlet NSTextField			*timerAmountField;
	IBOutlet NSButton				*minimizeWhileWaitingSwitch;

	IBOutlet NSButton				*checkVersionSwitch;
	IBOutlet NSButton				*checkVersionNowButton;
	IBOutlet NSProgressIndicator	*checkVersionProgress;
	IBOutlet NSTextField			*versionCheckStatusText;

	IBOutlet NSButton				*doneButton;
}

- (void)		doEditPreferences:(starfishPrefs*)prefs from:(StarfishController*)sender hasAV:(BOOL)canUseAltivec hasMP:(BOOL)canUseMP;
- (BOOL)		editingPrefs;
- (void)		handleNewVersionSheet:(NSString*)newVersion;
- (void)		setVersionCheckStatus;

- (IBAction) changedFileFormat:(id)sender;
- (IBAction) changedPrioritySwitch:(id)sender;
- (IBAction) changedQuitWhenDone:(id)sender;
- (IBAction) changedUseTimer:(id)sender;
- (IBAction) done:(id)sender;
- (IBAction) doCheckVersion:(id)sender;


@end
