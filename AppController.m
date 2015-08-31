#import "AppController.h"
#import "PaletteWindowController.h"
#import "PathExtra.h"
#import "WindowVisibilityController.h"
#import "DonationReminder/DonationReminder.h"
#import "NSRunningApplication+SmartActivate.h"
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
	if (![[NSRunningApplication runningApplicationsWithBundleIdentifier:@"net.mimikaki.mi"] count]) {
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
	id factorySetting = [_factoryDefaults objectForKey:theKey];
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject:factorySetting forKey:theKey];
}

- (id)factoryDefaultForKey:(NSString *)theKey
{
	return [_factoryDefaults objectForKey:theKey];
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
	if (!_settingWindow) {
		self.settingWindow = [[SettingWindowController alloc]
                              initWithWindowNibName:@"Setting"];
	}
	[_settingWindow showWindow:self];
	[NSRunningApplication activateSelf];
}

- (IBAction)quickTypesetPreview:(id)sender
{
	[_texBridgeController performHandler:@"quick_typeset_preview"];

}
- (IBAction)dviPreview:(id)sender
{
	[_texBridgeController performHandler:@"preview_dvi"];
	 
}
- (IBAction)dviToPDF:(id)sender
{
	[_texBridgeController performHandler:@"dvi_to_pdf"];
	
}
- (IBAction)typesetPDFPreview:(id)sender
{
	[_texBridgeController performHandler:@"typeset_preview_pdf"];
}

- (void)showStatusMessage:(NSString *)msg
{
	if (!_toolPaletteController) return;
	if (! [_toolPaletteController isOpened]) return;
	if ([_toolPaletteController isCollapsed]) return;
	[_toolPaletteController showStatusMessage:msg];
}

- (IBAction)showToolPalette:(id)sender
{
	if (!_toolPaletteController) {
		self.toolPaletteController = [[NewToolPaletteController alloc]
									initWithWindowNibName:@"NewToolPalette"];
	}
	[_toolPaletteController showWindow:self];
}

- (void)toggleToolPalette
{
	if (!_toolPaletteController) {
		return [self showToolPalette:self];
	}
	
	if ([_toolPaletteController isOpened]) {
		return [_toolPaletteController close];
	}
	
	[_toolPaletteController showWindow:self];
}

#pragma mark control for reference palette
- (void)stopTimer
{
	if (!_refPanelController) return;
	[_refPanelController temporaryStopReloadTimer];
}

- (void)restartTimer
{
	if (!_refPanelController) return;
	[_refPanelController restartReloadTimer];
}

- (void)rebuildLabelsFromAux:(NSString *)texFilePath textEncoding:(NSString *)encodingName
{
	if (!_refPanelController) return;
	if (![_refPanelController isOpened]) return;
	if ([_refPanelController isCollapsed]) return;
	[_refPanelController rebuildLabelsFromAux:texFilePath textEncoding:encodingName];
}

- (IBAction)showRefPalette:(id)sender
{
	if (!_refPanelController) {
		self.refPanelController = [[NewRefPanelController alloc]
								initWithWindowNibName:@"NewReferencePalette"];
	}
	[_refPanelController showWindow:self];
}

- (void)toggleRefPalette
{
	if (!_refPanelController) {
		return [self showRefPalette:self];
	}
	
	if ([_refPanelController isOpened]) {
		return [_refPanelController close];
	}
	
	[_refPanelController showWindow:self];
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
	self.factoryDefaults = [NSDictionary dictionaryWithContentsOfFile:defaultsPlistPath];
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults registerDefaults:_factoryDefaults];
	if (! [[_texBridgeController checkGUIScripting] boolValue]) {
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
	
	[_texBridgeController setup];
#if useLog
	NSLog(@"end applicationWillFinishLaunching");
#endif		
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
#if useLog
	NSLog(@"start applicationDidFinishLaunching");
#endif
	self.appQuitTimer = [NSTimer scheduledTimerWithTimeInterval:60*60 target:self
												  selector:@selector(checkQuit:) 
												  userInfo:nil repeats:YES];
	
	NSNotificationCenter *notifyCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
	[notifyCenter addObserver:self selector:@selector(anApplicationIsTerminated:) 
						 name:NSWorkspaceDidTerminateApplicationNotification object:nil];

	id reminderWindow = [DonationReminder remindDonation];
	if (reminderWindow != nil) [NSApp activateIgnoringOtherApps:YES];
	
	
	NSUserDefaults *user_defaults = [NSUserDefaults standardUserDefaults];
	
	self.toolPaletteController = nil;
	if ([user_defaults boolForKey:@"ShowToolPaletteWhenLaunched"] 
			||  [user_defaults boolForKey:@"IsOpenedToolPalette"]) {
		[self  setStartupMessage:@"Opening Tool Palette..."];
		[self showToolPalette:self];
	}
	
	self.refPanelController = nil;
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

@end
