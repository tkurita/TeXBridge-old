#import "NewRefPanelController.h"

#define useLog 0

extern id EditorClient;

@implementation NewRefPanelController


#pragma mark methods for the timer
- (void)periodicReload:(NSTimer *)theTimer
{
	if ([[self window] isVisible] && ![self isCollapsed]) {
		[dataController watchEditorWithReloading:NO];
	}
}

- (void)restartReloadTimer
{
	if (isWorkedReloadTimer) {
		[self setReloadTimer];
	}
}

- (void)temporaryStopReloadTimer
{
	if (reloadTimer != nil) {
		[reloadTimer invalidate];
		[reloadTimer release];
		reloadTimer = nil;		
		isWorkedReloadTimer = YES;
	}
	else {
		isWorkedReloadTimer = NO;
	}
}

- (void)setReloadTimer
{
#if useLog
	NSLog(@"setReloadTimer");
#endif
	if (reloadTimer == nil) {
		reloadTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self 
													 selector:@selector(periodicReload:) 
													 userInfo:nil repeats:YES];
		[reloadTimer retain];

	} 
	else if (![reloadTimer isValid]) {
		[reloadTimer invalidate];
		[reloadTimer release];
		reloadTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self 
													 selector:@selector(periodicReload:) 
													 userInfo:nil repeats:YES];
		[reloadTimer retain];
	}
}

#pragma mark actions
- (IBAction)showWindow:(id)sender
{
	[super showWindow:self];
	[self setReloadTimer];
}

- (IBAction)forceReload:(id)sender
{
	[dataController watchEditorWithReloading:YES];
}

#pragma mark delegete methods
- (void)applicationWillTerminate:(NSNotification *)notification
{
	NSUserDefaults *user_defaults = [NSUserDefaults standardUserDefaults];
	[user_defaults setBool:[self isOpened] forKey:@"IsOpenedRefPalette"];
}

- (void)awakeFromNib
{
	[self setFrameName:@"ReferencePalettePalette"];
	[self setApplicationsFloatingOnFromDefaultName:@"ReferencePaletteApplicationsFloatingOn"];
	[self useFloating];
	[self useWindowCollapse];
	[dataController watchEditorWithReloading:NO];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationWillTerminate:)
												 name:NSApplicationWillTerminateNotification
											   object:NSApp];
}

- (BOOL)windowShouldClose:(id)sender
{

	if (reloadTimer != nil) {
		[reloadTimer invalidate];
		[reloadTimer release];
		reloadTimer = nil;
	}

	return [super windowShouldClose:sender];
	
	/* To support AppleScript Studio of MacOS 10.4 */
	[[self window] orderOut:self];
	return NO;
}

//texFileFilePath must be master file.
- (void)rebuildLabelsFromAux:(NSString *)texFilePath textEncoding:(NSString *)encodingName
{
	TeXDocument *tex_doc = [TeXDocument texDocumentWithPath:texFilePath textEncoding:encodingName];
	[dataController rebuildLabelsFromAuxForDoc:tex_doc];
}
@end

