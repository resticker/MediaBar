@import UserNotifications;

#import "AppDelegate.h"

#import "NSString+GetMediaBarVersion.h"
#import "MediaBar-Swift.h"

#import "CustomMutableURLRequest.h"

#import "Constants.h"

#import "GlobalState.h"

#define RETURN_VOID(EXP) { EXP; return; }


@interface AppDelegate ()

@property (weak) IBOutlet GlobalState *globalState;

@property (weak) IBOutlet NSUserDefaults *userDefaults;

@property (strong) NSStatusItem *statusItem;

@property (weak) IBOutlet NSPopover *popover;

@property (weak) IBOutlet NSMenu *menu;

@property (weak) IBOutlet NSWindow *positioningWindow;
@property (weak) IBOutlet NSView *positioningView;


@property (strong) NSWindowController *preferencesController;

@property BOOL showArtist;
@property BOOL showTitle;
@property BOOL showAlbum;
@property BOOL hideTextWhenPaused;
@property (strong) NSString *icon;
@property (strong) NSString *iconWhilePlaying;
@property NSInteger maximumWidth;


@property (strong) NSTimer *productHuntTimer;

//@property (strong) RACDisposable *interval;

@property (strong) NSPopover *welcomePopover;

@property (strong) MediaBarShortcuts *shortcuts;

@end

@implementation AppDelegate

- (void)showPopover:(NSStatusBarButton *)sender {
    if (self.popover.isShown) return;
    
    // Check if this is a right-click event
    NSEvent *currentEvent = NSApp.currentEvent;
    if (currentEvent.type == NSEventTypeRightMouseUp) {
        // Right-click: Show context menu
        NSPoint location = sender.bounds.origin;
        [self.menu popUpMenuPositioningItem:nil atLocation:location inView:sender];
        return;
    }
    
    // Left-click: Show popover
    NSRect rect = [sender.window convertRectToScreen:sender.frame];
    CGFloat xOffset = CGRectGetMidX(self.positioningWindow.contentView.frame) - CGRectGetMidX(sender.frame);
    CGFloat x = rect.origin.x - xOffset;
    CGFloat y = rect.origin.y;
    [self.positioningWindow setFrameOrigin:NSMakePoint(x, y)];
    [self.positioningWindow makeKeyAndOrderFront:self];
    [self.popover showRelativeToRect:self.positioningView.bounds ofView:self.positioningView preferredEdge:NSMinYEdge];
    self.positioningView.bounds = CGRectOffset(self.positioningView.bounds, 0, 22);
    
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)popoverDidClose:(NSNotification *)notification {
    self.positioningView.bounds = CGRectOffset(self.positioningView.bounds, 0, -22);
    [self.positioningWindow orderOut:self];
}


- (void)loadUserDefaults {
    self.showArtist = [self.userDefaults boolForKey:ShowArtistUserDefaultsKey];
    self.showTitle = [self.userDefaults boolForKey:ShowTitleUserDefaultsKey];
    self.showAlbum = [self.userDefaults boolForKey:ShowAlbumUserDefaultsKey];
    self.hideTextWhenPaused = [self.userDefaults boolForKey:HideTextWhenPausedUserDefaultsKey];
    self.icon = [self.userDefaults stringForKey:IconUserDefaultsKey];
    self.iconWhilePlaying = [self.userDefaults stringForKey:IconWhilePlayingUserDefaultsKey];
    self.maximumWidth = [self.userDefaults integerForKey:MaximumWidthUserDefaultsKey];
    self.globalState.skipBackwardDuration = [self.userDefaults integerForKey:SkipBackwardDurationUserDefaultsKey];
    self.globalState.skipForwardDuration = [self.userDefaults integerForKey:SkipForwardDurationUserDefaultsKey];
}


#pragma mark - User notification center delegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler API_AVAILABLE(macos(10.14)) {

    if ([response.notification.request.identifier hasPrefix:@"MBProductHuntRelease"] && [response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
        [NSWorkspace.sharedWorkspace openURL:[[NSURL alloc] initWithString:[response.notification.request.content.userInfo objectForKey:@"url"]]];
    }
    
    completionHandler();
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler API_AVAILABLE(macos(10.14)) {
    completionHandler(0);
}

#pragma mark - Application delegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self loadUserDefaults];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(infoDidChange)
                                               name:GlobalStateNotification.infoDidChange
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(popoverDidClose:)
                                               name:NSPopoverDidCloseNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(userDefaultsDidChange:)
                                               name:NSUserDefaultsDidChangeNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(setupCompleted:)
                                               name:SetupCompletedNotificationName
                                             object:nil];
    
    
    self.shortcuts = [MediaBarShortcuts shared];
    [self setupGlobalShortcuts];

    
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.lineBreakMode = NSLineBreakByTruncatingTail;
    self.statusItem.button.target = self;
    self.statusItem.button.action = @selector(showPopover:);
    [self.statusItem.button sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];
    
    // Initial icon display - this will be properly formatted by infoDidChange
    [self infoDidChange];
    
    self.positioningWindow.opaque = YES;
    self.positioningWindow.backgroundColor = NSColor.clearColor;
    self.positioningWindow.level = kCGMaximumWindowLevel | kCGFloatingWindowLevel;
    self.positioningWindow.ignoresMouseEvents = YES;
    
#ifdef DEBUG
    [self.userDefaults setBool:NO forKey:ProductHuntNotificationDisplayedUserDefaultsKey];
#endif
    
//    if (@available(macOS 10.14, *)) {
//        UNUserNotificationCenter.currentNotificationCenter.delegate = self;
//        [UNUserNotificationCenter.currentNotificationCenter removeDeliveredNotificationsWithIdentifiers:@[@"MBNewUpdateAvailable"]];
//
//        if ([self.userDefaults boolForKey:EnableAutomaticUpdatesUserDefaultsKey]) {
//            [self checkForProductHuntRelease];
//        }
//    }
    
    if (![self.userDefaults boolForKey:SetupCompletedUserDefaultsKey]) {
        self.statusItem.button.action = nil;
        self.welcomePopover = [NSPopover new];
        self.welcomePopover.contentViewController = [[NSStoryboard storyboardWithName:@"Welcome Popover" bundle:nil] instantiateInitialController];
        [self.welcomePopover showRelativeToRect:self.statusItem.button.bounds ofView:self.statusItem.button preferredEdge:NSMinYEdge];
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [self.popover close];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notification handlers

- (void)setupCompleted:(NSNotification *)notification {
    self.statusItem.button.action = @selector(showPopover:);
    [self.welcomePopover close];
    self.welcomePopover = nil;
    [self.userDefaults setBool:YES forKey:SetupCompletedUserDefaultsKey];
}

- (void)userDefaultsDidChange:(NSNotification *)notification {
    if (notification != nil && notification.object == NSUserDefaults.standardUserDefaults) return;
    NSLog(@"User defaults did change");
    
    [self loadUserDefaults];
    if ([NSThread isMainThread]) {
        [self infoDidChange];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self infoDidChange];
        });
    }
}

- (void)infoDidChange {
    NSLog(@"infoDidChange called - artist: %@, title: %@, isPlaying: %@", 
          self.globalState.artist, self.globalState.title, 
          self.globalState.isPlaying ? @"YES" : @"NO");
    
#ifdef DEBUG
    static NSDate *lastUpdateTime = nil;
    NSDate *now = [NSDate date];
    NSTimeInterval timeSinceLastUpdate = lastUpdateTime ? [now timeIntervalSinceDate:lastUpdateTime] : 0;
    lastUpdateTime = now;
    
    NSLog(@"🔍 [DEBUG] Display Logic Check (%.3fs since last):", timeSinceLastUpdate);
    NSLog(@"  - isPlaying: %@", self.globalState.isPlaying ? @"YES" : @"NO");
    NSLog(@"  - hideTextWhenPaused: %@", self.hideTextWhenPaused ? @"YES" : @"NO");
    NSLog(@"  - showArtist: %@, showTitle: %@, showAlbum: %@", 
          self.showArtist ? @"YES" : @"NO", 
          self.showTitle ? @"YES" : @"NO", 
          self.showAlbum ? @"YES" : @"NO");
    NSLog(@"  - Media data: artist='%@', title='%@', album='%@'", 
          self.globalState.artist ?: @"(nil)", 
          self.globalState.title ?: @"(nil)", 
          self.globalState.album ?: @"(nil)");
    NSLog(@"  - Will show text: %@", 
          (self.globalState.isPlaying || !self.hideTextWhenPaused) ? @"YES" : @"NO");
#endif
    
    NSMutableAttributedString *title = [[NSMutableAttributedString alloc] init];
    if (self.icon.length > 0) {
        NSString *toAppend = [NSString stringWithFormat:@"%@ ", self.icon];
        [title.mutableString appendString:toAppend];
        [title addAttribute:NSFontAttributeName value:StatusItemIconFont range:NSMakeRange(0, self.icon.length)];
        [title addAttribute:NSFontAttributeName value:StatusItemTextFont range:NSMakeRange(self.icon.length, 1)];
    }
    
    if (self.iconWhilePlaying.length > 0 && self.globalState.isPlaying) {
        NSString *toAppend = [NSString stringWithFormat:@"%@ ", self.iconWhilePlaying];
        NSUInteger lengthBeforeAppend = title.mutableString.length;
        [title.mutableString appendString:toAppend];
        [title addAttribute:NSFontAttributeName value:StatusItemIconFont range:NSMakeRange(lengthBeforeAppend, self.iconWhilePlaying.length)];
        [title addAttribute:NSFontAttributeName value:StatusItemTextFont range:NSMakeRange(lengthBeforeAppend + self.iconWhilePlaying.length, 1)];
    }
    
    if (self.globalState.isPlaying || !self.hideTextWhenPaused) {
        NSMutableArray<NSString *> *artistTitleAlbum = [[NSMutableArray alloc] initWithCapacity:3];
        
        if (self.globalState.artist != nil && self.showArtist) [artistTitleAlbum addObject:self.globalState.artist];
        if (self.globalState.title != nil && self.showTitle) [artistTitleAlbum addObject:self.globalState.title];
        if (self.globalState.album != nil && self.showAlbum) [artistTitleAlbum addObject:self.globalState.album];

#ifdef DEBUG
        NSLog(@"  - Text components to show: %@", artistTitleAlbum);
        NSLog(@"  - Component count: %lu", (unsigned long)artistTitleAlbum.count);
#endif

        if (artistTitleAlbum.count == 1) {
            NSString *toAppend = [artistTitleAlbum objectAtIndex:0];
            NSUInteger lengthBeforeAppend = title.mutableString.length;
            [title.mutableString appendString:toAppend];
            [title addAttribute:NSFontAttributeName value:StatusItemTextFont range:NSMakeRange(lengthBeforeAppend, toAppend.length)];
        } else if (artistTitleAlbum.count == 2) {
            NSString *toAppend = [NSString stringWithFormat:@"%@ - %@", [artistTitleAlbum objectAtIndex:0], [artistTitleAlbum objectAtIndex:1]];
            NSUInteger lengthBeforeAppend = title.mutableString.length;
            [title.mutableString appendString:toAppend];
            [title addAttribute:NSFontAttributeName value:StatusItemTextFont range:NSMakeRange(lengthBeforeAppend, toAppend.length)];
        } else if (artistTitleAlbum.count == 3) {
            NSString *toAppend = [NSString stringWithFormat:@"%@ - %@ - %@", [artistTitleAlbum objectAtIndex:0], [artistTitleAlbum objectAtIndex:1], [artistTitleAlbum objectAtIndex:2]];
            NSUInteger lengthBeforeAppend = title.mutableString.length;
            [title.mutableString appendString:toAppend];
            [title addAttribute:NSFontAttributeName value:StatusItemTextFont range:NSMakeRange(lengthBeforeAppend, toAppend.length)];
        }
    }
#ifdef DEBUG
    else {
        NSLog(@"  - Text display SKIPPED: paused and hideTextWhenPaused is enabled");
    }
#endif
    
    CGFloat padding = 10;
    CGFloat titleWidth = ceil(title.size.width) + 2;
    CGFloat widthWithPadding = titleWidth + padding;
    CGFloat newWidth = widthWithPadding > self.maximumWidth ? self.maximumWidth : widthWithPadding;
    self.statusItem.length = newWidth;
    self.statusItem.button.frame = CGRectMake(padding / 2, 0, newWidth - padding, 22);
    self.statusItem.button.attributedTitle = title;
    
#ifdef DEBUG
    NSLog(@"  - Final display: '%@' (width: %.1f)", title.string, newWidth);
    NSLog(@"🔍 [DEBUG] Display update complete\n");
#endif
    
    if (self.welcomePopover != nil) {
        [self.welcomePopover showRelativeToRect:self.statusItem.button.bounds ofView:self.statusItem.button preferredEdge:NSMinYEdge];
    }
}

#pragma mark - Actions

- (IBAction)preferencesAction:(NSMenuItem *)sender {
    NSLog(@"Should show preferences");
    
    if (self.preferencesController == nil) {
        NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Preferences" bundle:nil];
        self.preferencesController = [storyboard instantiateInitialController];
    }
    
    [self.preferencesController showWindow:self];
    [self.preferencesController.window makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
}

//- (void)playPauseShortcutAction
//{
//    [self.globalState togglePlayPause];
//}
//
//- (void)skipForwardShortcutAction
//{
//    [self.globalState skipForward];
//}
//
//- (void)skipBackwardShortcutAction
//{
//    [self.globalState skipBackward];
//}

- (void)setupGlobalShortcuts {

    __weak typeof(self) weakSelf = self;
    
    [self.shortcuts setupGlobalShortcutsWithPlayPauseAction:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.globalState togglePlayPause];
    } previousAction:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.globalState previous];
    } nextAction:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.globalState next];
    } skipBackwardAction:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.globalState skipBackward];
    } skipForwardAction:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.globalState skipForward];
    }];
}

@end
