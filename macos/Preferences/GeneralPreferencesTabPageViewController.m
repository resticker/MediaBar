@import DNLoginServiceKit;

#import "GeneralPreferencesTabPageViewController.h"

#import "Constants.h"

#import "PreferencesCheckbox.h"
#import "PreferencesPopUpButton.h"
#import <MASShortcut/Shortcut.h>

static NSString *const kPreferenceGlobalShortcut = @"GlobalShortcut";

@interface GeneralPreferencesTabPageViewController ()

@property (strong) IBOutlet NSUserDefaults *userDefaults;

@property (weak) IBOutlet PreferencesCheckbox *showArtistCheckbox;
@property (weak) IBOutlet PreferencesCheckbox *showTitleCheckbox;
@property (weak) IBOutlet PreferencesCheckbox *showAlbumCheckbox;
@property (weak) IBOutlet PreferencesCheckbox *hideTextWhenPausedCheckbox;
@property (weak) IBOutlet PreferencesCheckbox *enableAutomaticUpdatesCheckbox;
@property (weak) IBOutlet PreferencesCheckbox *enableErrorReportingCheckbox;
@property (weak) IBOutlet PreferencesPopUpButton *iconPopUpButton;
@property (weak) IBOutlet PreferencesPopUpButton *iconWhilePlayingPopUpButton;
@property (nonatomic, weak) IBOutlet MASShortcutView *shortcutView;

@property (weak) IBOutlet NSButton *launchAtLoginCheckbox;

@property (weak) IBOutlet NSSlider *maximumWidthSlider;

@end

@implementation GeneralPreferencesTabPageViewController

- (void)setupCheckbox:(PreferencesCheckbox *)checkbox userDefaultsKey:(NSString *)key {
    checkbox.userDefaultsKey = key;
    checkbox.state = [self.userDefaults boolForKey:key] ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)setupPopUpBox:(PreferencesPopUpButton *)popUpButton userDefaultsKey:(NSString *)key {
    popUpButton.userDefaultsKey = key;
    NSString *currentValue = [self.userDefaults stringForKey:key];
    [popUpButton selectItemWithTitle:currentValue.length == 0 ? @"None" : currentValue];
    popUpButton.font = StatusItemIconFont;
}

#pragma mark - View controller

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.shortcutView.associatedUserDefaultsKey = kPreferenceGlobalShortcut;
    
    
    // Most apps need default shortcut, delete these lines if this is not your case
//    MASShortcut *firstLaunchShortcut = [MASShortcut shortcutWithKeyCode:kVK_F1 modifierFlags:NSEventModifierFlagCommand];
//    NSData *firstLaunchShortcutData = [NSKeyedArchiver archivedDataWithRootObject:firstLaunchShortcut];
    
//    [userDefaults registerDefaults:@{
//        MASHardcodedShortcutEnabledKey : @YES,
//        MASCustomShortcutEnabledKey : @YES,
//        MASCustomShortcutKey : firstLaunchShortcutData
//        kPreferenceGlobalShortcut : firstLaunchShortcutData
//    }];
    
    
    [self setupCheckbox:self.showArtistCheckbox userDefaultsKey:ShowArtistUserDefaultsKey];
    [self setupCheckbox:self.showTitleCheckbox userDefaultsKey:ShowTitleUserDefaultsKey];
    [self setupCheckbox:self.showAlbumCheckbox userDefaultsKey:ShowAlbumUserDefaultsKey];
    [self setupCheckbox:self.hideTextWhenPausedCheckbox userDefaultsKey:HideTextWhenPausedUserDefaultsKey];
    [self setupCheckbox:self.enableAutomaticUpdatesCheckbox userDefaultsKey:EnableAutomaticUpdatesUserDefaultsKey];
    [self setupCheckbox:self.enableErrorReportingCheckbox userDefaultsKey:EnableErrorReportingUserDefaultsKey];
    [self setupPopUpBox:self.iconPopUpButton userDefaultsKey:IconUserDefaultsKey];
    [self setupPopUpBox:self.iconWhilePlayingPopUpButton userDefaultsKey:IconWhilePlayingUserDefaultsKey];
    
    NSInteger maximumWidth = [self.userDefaults integerForKey:MaximumWidthUserDefaultsKey];
    self.maximumWidthSlider.integerValue = maximumWidth;
    
    self.launchAtLoginCheckbox.state = DNLoginServiceKit.loginItemExists ? NSControlStateValueOn : NSControlStateValueOff;
    
    [[MASShortcutBinder sharedBinder]
        bindShortcutWithDefaultsKey:kPreferenceGlobalShortcut
        toAction:^{
            [self playShortcutFeedback];
        // Let me know if you find a better or a more convenient API.
    }];
}

- (void)playShortcutFeedback
{
    [[NSSound soundNamed:@"Ping"] play];
//    [self.feedbackTextField setStringValue:NSLocalizedString(@"Shortcut pressed!", @"Feedback that’s displayed when user presses the sample shortcut.")];
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self.feedbackTextField setStringValue:@""];
//    });
}

#pragma mark - Actions

- (IBAction)booleanAction:(PreferencesCheckbox *)sender {
    [self.userDefaults setBool:sender.state == NSControlStateValueOn forKey:sender.userDefaultsKey];
}

- (IBAction)launchAtLoginCheckboxAction:(NSButton *)sender {
    if (self.launchAtLoginCheckbox.state == NSControlStateValueOn) {
        [DNLoginServiceKit addLoginItem];
    } else {
        [DNLoginServiceKit removeLoginItem];
    }
}

- (IBAction)popUpBoxAction:(PreferencesPopUpButton *)sender {
    NSString *currentValue = sender.selectedItem.title;
    [self.userDefaults setObject:[currentValue compare:@"None"] == NSOrderedSame ? @"" : currentValue
                          forKey:sender.userDefaultsKey];
}

- (IBAction)maximumWidthSliderAction:(NSSlider *)sender {
    [self.userDefaults setInteger:sender.integerValue forKey:MaximumWidthUserDefaultsKey];
}

@end
