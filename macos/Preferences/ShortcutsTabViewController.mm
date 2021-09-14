#import "ShortcutsTabViewController.h"
#import <MASShortcut/Shortcut.h>

#import "GlobalState.h"

static NSString *const kPreferenceGlobalShortcut = @"GlobalShortcut";

static void *kGlobalShortcutContext = &kGlobalShortcutContext;

NSString *_observableKeyPath;

@interface ShortcutsTabViewController ()

@property (nonatomic, weak) IBOutlet MASShortcutView *shortcutView;
@property (strong) IBOutlet GlobalState *globalState; // This reference was becoming nil until I switched it from weak to strong

@end

@implementation ShortcutsTabViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.shortcutView.associatedUserDefaultsKey = kPreferenceGlobalShortcut;
    
    [[MASShortcutBinder sharedBinder]
        bindShortcutWithDefaultsKey:kPreferenceGlobalShortcut
        toAction:^{
            [self playShortcutFeedback];
        // Let me know if you find a better or a more convenient API.
    }];
    
    _observableKeyPath = [@"values." stringByAppendingString:kPreferenceGlobalShortcut];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:_observableKeyPath
                                                                 options:NSKeyValueObservingOptionInitial
                                                                 context:kGlobalShortcutContext];
    
    self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
    
    NSLog(@"self.global State object is (from viewDidLoad): %@", self.globalState);
//    [self.globalState togglePlayPause];
//    [self playShortcutFeedback];
}

- (void)viewWillAppear {
    NSLog(@"TEST...");
    NSLog(@"self.global State object is (from viewDidLoad): %@", self.globalState);
}

- (void)playShortcutFeedback
{
    NSLog(@"self.global State object is: %@", self.globalState);
//    NSLog(@"togglePlayPause object is: %@", [self.globalState togglePlayPause]);
    
    NSLog(@"trying to access global state");
    [self.globalState togglePlayPause];
    NSLog(@"pressed sound shortcut");
    [[NSSound soundNamed:@"Ping"] play];
//    [self.feedbackTextField setStringValue:NSLocalizedString(@"Shortcut pressed!", @"Feedback that’s displayed when user presses the sample shortcut.")];
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self.feedbackTextField setStringValue:@""];
//    });
}

- (IBAction)playPauseAction:(NSButton *)sender {
    NSLog(@"play pause from button");
    [self.globalState togglePlayPause];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)obj
                        change:(NSDictionary *)change context:(void *)ctx
{
    NSLog(@"in observeValueForKeyPath");
    
    
    
    if (ctx == kGlobalShortcutContext) {
        NSLog(@"Shortcut has changed");
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:obj change:change context:ctx];
    }
}

@end
