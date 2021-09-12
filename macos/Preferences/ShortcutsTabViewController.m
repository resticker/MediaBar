#import "ShortcutsTabViewController.h"
#import <MASShortcut/Shortcut.h>

static NSString *const kPreferenceGlobalShortcut = @"GlobalShortcut";

@interface ShortcutsTabViewController ()

@property (nonatomic, weak) IBOutlet MASShortcutView *shortcutView;
//@property(strong) IBOutlet MASShortcutView *shortcutView;

@end

@implementation ShortcutsTabViewController

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
    
    [[MASShortcutBinder sharedBinder]
        bindShortcutWithDefaultsKey:kPreferenceGlobalShortcut
        toAction:^{
            [self playShortcutFeedback];
        // Let me know if you find a better or a more convenient API.
    }];
    
    self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
}

- (void)playShortcutFeedback
{
    NSLog(@"pressed sound shortcut");
    [[NSSound soundNamed:@"Ping"] play];
//    [self.feedbackTextField setStringValue:NSLocalizedString(@"Shortcut pressed!", @"Feedback that’s displayed when user presses the sample shortcut.")];
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self.feedbackTextField setStringValue:@""];
//    });
}

- (IBAction)githubButtonAction:(NSButton *)sender {
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://github.com/dimitarnestorov/MusicBar"]];
}

@end
