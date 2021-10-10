#import "ShortcutsTabViewController.h"
#import <MASShortcut/Shortcut.h>

#import "GlobalState.h"

static NSString *const kPreferenceGlobalShortcutPlayPause = @"GlobalShortcut";
static NSString *const kPreferenceGlobalShortcutSkipBackward = @"SkipBackwardShortcut";
static NSString *const kPreferenceGlobalShortcutSkipForward = @"SkipForwardShortcut";

static void *kGlobalShortcutContext = &kGlobalShortcutContext;

NSString *_observableKeyPathPlayPause;
NSString *_observableKeyPathSkipBackward;
NSString *_observableKeyPathSkipForward;

@interface ShortcutsTabViewController ()

@property (nonatomic, weak) IBOutlet MASShortcutView *playPauseShortcutView;
@property (nonatomic, weak) IBOutlet MASShortcutView *skipBackwardShortcutView;
@property (nonatomic, weak) IBOutlet MASShortcutView *skipForwardShortcutView;
@property (strong) IBOutlet GlobalState *globalState; // This reference was becoming nil until I switched it from weak to strong

@end

@implementation ShortcutsTabViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.playPauseShortcutView.associatedUserDefaultsKey = kPreferenceGlobalShortcutPlayPause;
    self.skipBackwardShortcutView.associatedUserDefaultsKey = kPreferenceGlobalShortcutSkipBackward;
    self.skipForwardShortcutView.associatedUserDefaultsKey = kPreferenceGlobalShortcutSkipForward;
    
    [[MASShortcutBinder sharedBinder]
        bindShortcutWithDefaultsKey:kPreferenceGlobalShortcutPlayPause
        toAction:^{
            [self playPauseShortcutAction];
        // Let me know if you find a better or a more convenient API.
    }];
    
    [[MASShortcutBinder sharedBinder]
        bindShortcutWithDefaultsKey:kPreferenceGlobalShortcutSkipBackward
        toAction:^{
            [self skipBackwardShortcutAction];
        // Let me know if you find a better or a more convenient API.
    }];
    
    [[MASShortcutBinder sharedBinder]
        bindShortcutWithDefaultsKey:kPreferenceGlobalShortcutSkipForward
        toAction:^{
            [self skipForwardShortcutAction];
        // Let me know if you find a better or a more convenient API.
    }];

    _observableKeyPathPlayPause = [@"values." stringByAppendingString:kPreferenceGlobalShortcutPlayPause];
    _observableKeyPathSkipBackward = [@"values." stringByAppendingString:kPreferenceGlobalShortcutSkipBackward];
    _observableKeyPathSkipForward = [@"values." stringByAppendingString:kPreferenceGlobalShortcutSkipForward];
    
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:_observableKeyPathPlayPause
                                                                 options:NSKeyValueObservingOptionInitial
                                                                 context:kGlobalShortcutContext];
    
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:_observableKeyPathSkipBackward
                                                                 options:NSKeyValueObservingOptionInitial
                                                                 context:kGlobalShortcutContext];
        
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:_observableKeyPathSkipForward
                                                                 options:NSKeyValueObservingOptionInitial
                                                                 context:kGlobalShortcutContext];
    
    self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
    
    NSLog(@"self.global State object is (from viewDidLoad): %@", self.globalState);
}

//- (void)viewWillAppear {
//    NSLog(@"TEST...");
//    NSLog(@"self.global State object is (from viewDidLoad): %@", self.globalState);
//}

- (void)playPauseShortcutAction
{
//    NSLog(@"self.global State object is: %@", self.globalState);
//    NSLog(@"togglePlayPause object is: %@", [self.globalState togglePlayPause]);
    
//    NSLog(@"trying to access global state");
    [self.globalState togglePlayPause];
    NSLog(@"pressed playPause shortcut");
    [[NSSound soundNamed:@"Frog"] play];
}

- (void)skipForwardShortcutAction
{
    [self.globalState skipForward];
    NSLog(@"pressed skipforward shortcut");
    [[NSSound soundNamed:@"Ping"] play];
}

- (void)skipBackwardShortcutAction
{
    [self.globalState skipBackward];
    NSLog(@"pressed skipbackward shortcut");
    [[NSSound soundNamed:@"Purr"] play];
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
