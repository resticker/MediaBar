#import "ShortcutsTabViewController.h"
#import <MASShortcut/Shortcut.h>

#import "Constants.h"
#import "GlobalState.h"


static void *kGlobalShortcutContext = &kGlobalShortcutContext;


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
    
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:kPreferenceGlobalShortcutPlayPause
                                                                 options:NSKeyValueObservingOptionInitial
                                                                 context:kGlobalShortcutContext];
    
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:kPreferenceGlobalShortcutSkipBackward
                                                                 options:NSKeyValueObservingOptionInitial
                                                                 context:kGlobalShortcutContext];
        
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:kPreferenceGlobalShortcutSkipForward
                                                                 options:NSKeyValueObservingOptionInitial
                                                                 context:kGlobalShortcutContext];
    
    self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
    
    NSLog(@"self.global State object is (from viewDidLoad): %@", self.globalState);
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
