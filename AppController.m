#import "AppController.h"
#import "CocoaLib/PaletteWindowController.h"
#import "CocoaLib/PathExtra.h"
#import "CocoaLib/WindowVisibilityController.h"
#import "DonationReminder/DonationReminder.h"
#import "SmartActivate.h"
#import "TeXDocument.h"
#import "NewRefPanelController.h"
#import "DVIPreviewModeTransformer.h"

#define useLog 0

id EditorClient;
static id sharedObj = nil;

NSArray *orderdEncodingCandidates(NSString *firstCandidateName)
{
	NSMutableArray *encoding_table = [[[NSUserDefaults standardUserDefaults] 
											arrayForKey:@"EncodingTable"] mutableCopy];
	if (firstCandidateName) {
		NSPredicate *a_predicate = [NSPredicate predicateWithFormat:@"name == %@", firstCandidateName];
		NSDictionary *first_candidate = [[encoding_table filteredArrayUsingPredicate:a_predicate] lastObject];
		[encoding_table removeObject:first_candidate];
		[encoding_table insertObject:first_candidate atIndex:0];
	}
	return [encoding_table valueForKey:@"id"];
}

@implementation AppController

+ (void)initialize	// Early initialization
{		
	if ([AppController class] == self) {
        sharedObj = nil;
		[NSValueTransformer setValueTransformer:[DVIPreviewModeTransformer new] forName:@"DVIPreviewModeTransformer"];
    }
}

+ (id)sharedAppController
{
	@synchronized(self) {
		if (sharedObj == nil) {
			(void) [[self alloc] init]; // �����ł͑�����Ă��Ȃ�
		}
	}
    return sharedObj;
}

+ (id)allocWithZone:(NSZone *)zone {  
    @synchronized(self) {  
        if (sharedObj == nil) {  
            sharedObj = [super allocWithZone:zone];  
            return sharedObj;  
        }  
    }  
    return nil;  
}  

- (id)copyWithZone:(NSZone*)zone {  
    return self;  // �V���O���g����Ԃ�ێ����邽�߉������� self ��Ԃ�  
}  

- (void)checkQuit:(NSTimer *)aTimer
{
	NSArray *appList = [[NSWorkspace sharedWorkspace] launchedApplications];
	NSEnumerator *enumerator = [appList objectEnumerator];
	
	id appDict;
	BOOL isMiLaunched = NO;
	while (appDict = [enumerator nextObject]) {
		NSString *app_identifier = [appDict objectForKey:@"NSApplicationBundleIdentifier"];
		if ([app_identifier isEqualToString:@"net.mimikaki.mi"] ) {
			isMiLaunched = YES;
			break;
		}		
	}
	
	if (! isMiLaunched) {
		[NSApp terminate:self];
	}
}

- (void)anApplicationIsTerminated:(NSNotification *)aNotification
{
#if useLog
	NSLog(@"anApplicationIsTerminated");
#endif
	NSDictionary *user_info = [aNotification userInfo];
	NSString *identifier = [user_info objectForKey:@"NSApplicationBundleIdentifier"];
	if ([identifier isEqualToString:@"net.mimikaki.mi"] ) [[NSApplication sharedApplication] terminate:self];
	
}

- (void)revertToFactoryDefaultForKey:(NSString *)theKey
{
	id factorySetting = [factoryDefaults objectForKey:theKey];
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject:factorySetting forKey:theKey];
}

- (id)factoryDefaultForKey:(NSString *)theKey
{
	return [factoryDefaults objectForKey:theKey];
}

- (int)judgeVisibilityForApp:(NSDictionary *)appDict
{
	/*
	result = -1 : can't judge in this routine
	0 : should hide	
	1: should show
	2: should not change
	*/
	if (! appDict) {
		return kShouldHide;
	}
	
	NSString *app_name = [appDict objectForKey:@"NSApplicationName"];

	if ([app_name isEqualToString:[EditorClient name]]) {
		NSString *theMode;
		@try{
			theMode = [EditorClient currentDocumentMode];
		}
		@catch(NSException *exception){
			#if useLog
			NSLog(@"%@", [exception description]);
			#endif
			 NSNumber *err = [[exception userInfo] objectForKey:@"result code"];
			 if ([err intValue] == -1704) {
				 // maybe menu is opened
				 return kShouldNotChange;
			 }
			 else {
				 // maybe no documents opened
				 return kShouldHide;
			 }	
		 }
		 #if useLog
		 NSLog(@"current mode : %@", theMode);
		 #endif
		 
		 if (!theMode) {
			// may AESendMessage time outed
			return kShouldNotChange;
		 }
		 
		 if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"SupportedModes"]
				containsObject:theMode]) {
			 return kShouldShow;
		 } else {
			 return kShouldHide;
		 }
	 }
	return kShouldPostController;
}

- (void)setStartupMessage:(NSString *)message
{
	[startupMessageField setStringValue:message];
	[startupWindow displayIfNeeded];
}

#pragma mark actions for tool palette

- (IBAction)showSettingWindow:(id)sender
{
	if (!settingWindow) {
		settingWindow = [[SettingWindowController alloc] initWithWindowNibName:@"Setting"];
	}
	[settingWindow showWindow:self];
	[SmartActivate activateSelf];
}

- (IBAction)quickTypesetPreview:(id)sender
{
	[texBridgeController performHandler:@"quick_typeset_preview"];

}
- (IBAction)dviPreview:(id)sender
{
	[texBridgeController performHandler:@"preview_dvi"];
	 
}
- (IBAction)dviToPDF:(id)sender
{
	[texBridgeController performHandler:@"dvi_to_pdf"];
	
}
- (IBAction)typesetPDFPreview:(id)sender
{
	[texBridgeController performHandler:@"typeset_preview_pdf"];
}

- (void)showStatusMessage:(NSString *)msg
{
	if (! toolPaletteController) return;
	if (! [toolPaletteController isOpened]) return;
	if ([toolPaletteController isCollapsed]) return;
	[toolPaletteController showStatusMessage:msg];
}

- (IBAction)showToolPalette:(id)sender
{
	if (!toolPaletteController) {
		toolPaletteController = [[NewToolPaletteController alloc] 
									initWithWindowNibName:@"NewToolPalette"];
	}
	[toolPaletteController showWindow:self];
}

- (void)toggleToolPalette
{
	if (!toolPaletteController) {
		return [self showToolPalette:self];
	}
	
	if ([toolPaletteController isOpened]) {
		return [toolPaletteController close];
	}
	
	[toolPaletteController showWindow:self];
}

#pragma mark control for reference palette
- (void)stopTimer
{
	if (!refPanelController) return;
	[refPanelController temporaryStopReloadTimer];
}

- (void)restartTimer
{
	if (!refPanelController) return;
	[refPanelController restartReloadTimer];
}

- (void)rebuildLabelsFromAux:(NSString *)texFilePath textEncoding:(NSString *)encodingName
{
	if (!refPanelController) return;
	if (![refPanelController isOpened]) return;
	if ([refPanelController isCollapsed]) return;
	[refPanelController rebuildLabelsFromAux:texFilePath textEncoding:encodingName];
}

- (IBAction)showRefPalette:(id)sender
{
	if (!refPanelController) {
		refPanelController = [[NewRefPanelController alloc]
								initWithWindowNibName:@"NewReferencePalette"];
	}
	[refPanelController showWindow:self];
}

- (void)toggleRefPalette
{
	if (!refPanelController) {
		return [self showRefPalette:self];
	}
	
	if ([refPanelController isOpened]) {
		return [refPanelController close];
	}
	
	[refPanelController showWindow:self];
}

#pragma mark delegate of NSApplication
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
#if useLog
	NSLog(@"start applicationWillFinishLaunching");
#endif	
	/* regist FactorySettings into shared user defaults */
	NSString *defaultsPlistPath = [[NSBundle mainBundle] pathForResource:@"FactorySettings" 
																  ofType:@"plist"];
	factoryDefaults = [NSDictionary dictionaryWithContentsOfFile:defaultsPlistPath];
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults registerDefaults:factoryDefaults];
	if (! [[texBridgeController checkGUIScripting] boolValue]) {
#if useLog		
		NSLog(@"%@", @"should quit because checkGUIScripting is disabled.");
#endif		
		[NSApp terminate:nil];
		return;
	}
	
	/* checking checking UI Elements Scripting ... */
	/*
	if (!AXAPIEnabled())
    {
		[startupWindow close];
		[NSApp activateIgnoringOtherApps:YES];
		int ret = NSRunAlertPanel(NSLocalizedString(@"disableGUIScripting", ""), @"", 
								  NSLocalizedString(@"Launch System Preferences", ""),
								  NSLocalizedString(@"Cancel",""), @"");
		switch (ret)
        {
            case NSAlertDefaultReturn:
                [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/UniversalAccessPref.prefPane"];
                break;
			default:
                break;
        }
        
		[NSApp terminate:self];
		return;
    }*/
	[startupWindow orderFront:self];
	EditorClient = [miClient sharedClient];
	WindowVisibilityController *wvController = [[WindowVisibilityController alloc] init];
	[wvController setDelegate:self];
	[wvController setFocusWatchApplication:@"net.mimikaki.mi"];
	[PaletteWindowController setVisibilityController:wvController];
	
	[texBridgeController setup];
#if useLog
	NSLog(@"end applicationWillFinishLaunching");
#endif		
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
#if useLog
	NSLog(@"start applicationDidFinishLaunching");
#endif
	appQuitTimer = [NSTimer scheduledTimerWithTimeInterval:60*60 target:self 
												  selector:@selector(checkQuit:) 
												  userInfo:nil repeats:YES];
	
	NSNotificationCenter *notifyCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
	[notifyCenter addObserver:self selector:@selector(anApplicationIsTerminated:) 
						 name:NSWorkspaceDidTerminateApplicationNotification object:nil];

	id reminderWindow = [DonationReminder remindDonation];
	if (reminderWindow != nil) [NSApp activateIgnoringOtherApps:YES];
	
	
	NSUserDefaults *user_defaults = [NSUserDefaults standardUserDefaults];
	
	toolPaletteController = nil;
	if ([user_defaults boolForKey:@"ShowToolPaletteWhenLaunched"] 
			||  [user_defaults boolForKey:@"IsOpenedToolPalette"]) {
		[self  setStartupMessage:@"Opening Tool Palette..."];
		[self showToolPalette:self];
	}
	
	refPanelController = nil;
	if ([user_defaults boolForKey:@"ShowRefPaletteWhenLaunched"] 
		||  [user_defaults boolForKey:@"IsOpenedRefPalette"]) {
		[self setStartupMessage:@"Opening Reference Palette..."];
		[self showRefPalette:self];
	}
	

	// Test Code
	/*
	NewRefPanelController *wc = [[NewRefPanelController alloc] initWithWindowNibName:@"NewReferencePalette"];
	[wc showWindow:self];
	 */
	[startupWindow close];
#if useLog
	NSLog(@"end applicationDidFinishLaunching");
#endif	
}

#pragma mark Accessors

- (TeXBridgeController *)texBridgeController
{
	return texBridgeController;
}

@end
