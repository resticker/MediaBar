#import "ShortcutsTabViewController.h"
#import "MediaBar-Swift.h"

#import "Constants.h"
#import "GlobalState.h"


static void *kGlobalShortcutContext = &kGlobalShortcutContext;


@interface ShortcutsTabViewController ()

@property (nonatomic, weak) IBOutlet NSView *playPauseContainer;
@property (nonatomic, weak) IBOutlet NSView *previousTrackContainer;
@property (nonatomic, weak) IBOutlet NSView *nextTrackContainer;
@property (nonatomic, weak) IBOutlet NSView *skipBackwardContainer;
@property (nonatomic, weak) IBOutlet NSView *skipForwardContainer;

@property (nonatomic, strong) id playPauseRecorder;
@property (nonatomic, strong) id previousTrackRecorder;
@property (nonatomic, strong) id nextTrackRecorder;
@property (nonatomic, strong) id skipBackwardRecorder;
@property (nonatomic, strong) id skipForwardRecorder;

@property (strong) IBOutlet GlobalState *globalState; // This reference was becoming nil until I switched it from weak to strong

@end

@implementation ShortcutsTabViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create recorders after view is loaded
    dispatch_async(dispatch_get_main_queue(), ^{
        [self createKeyboardShortcutRecordersDirectly];
    });
    
    self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
}

- (void)createKeyboardShortcutRecordersDirectly {
    NSLog(@"🚀 Starting createKeyboardShortcutRecordersDirectly");
    
    // Find all labels in the view and replace them with recorders
    NSArray *shortcutTypes = @[@"playPause", @"previousTrack", @"nextTrack", @"skipBackward", @"skipForward"];
    NSArray *labels = @[@"Play/Pause", @"Previous Track", @"Next Track", @"Skip Backward", @"Skip Forward"];
    
    NSLog(@"🔍 Scanning view subviews. Total subviews: %lu", (unsigned long)self.view.subviews.count);
    
    // Look for NSGridView and traverse its structure
    for (NSView *subview in self.view.subviews) {
        NSLog(@"📋 Found subview: %@ of class: %@", subview, [subview class]);
        
        if ([subview isKindOfClass:[NSGridView class]]) {
            NSGridView *gridView = (NSGridView *)subview;
            NSLog(@"🔲 Found NSGridView with %lu rows", (unsigned long)gridView.numberOfRows);
            
            for (NSInteger row = 0; row < gridView.numberOfRows; row++) {
                NSGridRow *gridRow = [gridView rowAtIndex:row];
                NSLog(@"📍 Processing row %ld with %lu cells", row, (unsigned long)gridRow.numberOfCells);
                
                if (gridRow.numberOfCells >= 2) {
                    // First cell should contain the label, second cell should be empty for recorder
                    NSGridCell *labelCell = [gridRow cellAtIndex:0];
                    NSGridCell *recorderCell = [gridRow cellAtIndex:1];
                    
                    NSView *labelView = labelCell.contentView;
                    NSLog(@"🏷️ Label cell content: %@ of class: %@", labelView, [labelView class]);
                    
                    if ([labelView isKindOfClass:[NSTextField class]]) {
                        NSTextField *label = (NSTextField *)labelView;
                        NSString *labelText = label.stringValue;
                        NSLog(@"📝 Found label: '%@'", labelText);
                        
                        // Find matching shortcut type
                        NSInteger index = [labels indexOfObject:labelText];
                        if (index != NSNotFound) {
                            NSString *shortcutType = shortcutTypes[index];
                            NSLog(@"✅ Matched label '%@' to shortcut type '%@'", labelText, shortcutType);
                            
                            // Create recorder
                            NSLog(@"🔧 Calling createRecorderForShortcutType for: %@", shortcutType);
                            id recorder = [[MediaBarShortcuts shared] createRecorderForShortcutType:shortcutType];
                            NSLog(@"📦 Received recorder: %@", recorder);
                            
                            if (recorder && [recorder isKindOfClass:[NSView class]]) {
                                NSView *recorderView = (NSView *)recorder;
                                
                                // Set the recorder as the content of the second cell
                                recorderCell.contentView = recorderView;
                                
                                // Store the recorder
                                if ([shortcutType isEqualToString:@"playPause"]) {
                                    self.playPauseRecorder = recorder;
                                } else if ([shortcutType isEqualToString:@"previousTrack"]) {
                                    self.previousTrackRecorder = recorder;
                                } else if ([shortcutType isEqualToString:@"nextTrack"]) {
                                    self.nextTrackRecorder = recorder;
                                } else if ([shortcutType isEqualToString:@"skipBackward"]) {
                                    self.skipBackwardRecorder = recorder;
                                } else if ([shortcutType isEqualToString:@"skipForward"]) {
                                    self.skipForwardRecorder = recorder;
                                }
                                
                                NSLog(@"✅ Added recorder for %@ to grid cell", shortcutType);
                            } else {
                                NSLog(@"❌ Failed to create valid recorder for %@", shortcutType);
                            }
                        } else {
                            NSLog(@"❌ No match found for label: '%@'", labelText);
                        }
                    }
                }
            }
        }
        
        // Also check for individual text fields (fallback)
        if ([subview isKindOfClass:[NSTextField class]]) {
            NSTextField *label = (NSTextField *)subview;
            NSString *labelText = label.stringValue;
            NSLog(@"📝 Found standalone label: '%@'", labelText);
        }
    }
    NSLog(@"🏁 Finished createKeyboardShortcutRecordersDirectly");
}

- (void)createKeyboardShortcutRecorders {
    // Create RecorderCocoa instances for each shortcut using a helper method from our Swift bridge
    self.playPauseRecorder = [self createRecorderForContainer:self.playPauseContainer 
                                                 shortcutType:@"playPause"];
    
    self.previousTrackRecorder = [self createRecorderForContainer:self.previousTrackContainer 
                                                    shortcutType:@"previousTrack"];
    
    self.nextTrackRecorder = [self createRecorderForContainer:self.nextTrackContainer 
                                               shortcutType:@"nextTrack"];
    
    self.skipBackwardRecorder = [self createRecorderForContainer:self.skipBackwardContainer 
                                                  shortcutType:@"skipBackward"];
    
    self.skipForwardRecorder = [self createRecorderForContainer:self.skipForwardContainer 
                                                 shortcutType:@"skipForward"];
}

- (id)createRecorderForContainer:(NSView *)container shortcutType:(NSString *)shortcutType {
    if (!container) {
        NSLog(@"Container view not found for shortcut type: %@", shortcutType);
        return nil;
    }
    
    // Ensure we're on the main thread since the recorder creation requires @MainActor
    dispatch_async(dispatch_get_main_queue(), ^{
        [self createRecorderOnMainThread:container shortcutType:shortcutType];
    });
    
    return nil; // Return nil immediately, actual setup happens async
}

- (void)createRecorderOnMainThread:(NSView *)container shortcutType:(NSString *)shortcutType {
    // Use our MediaBarShortcuts bridge to create the recorder
    id recorder = [[MediaBarShortcuts shared] createRecorderForShortcutType:shortcutType];
    
    if (recorder && [recorder isKindOfClass:[NSView class]]) {
        NSView *recorderView = (NSView *)recorder;
        recorderView.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Clear container and add recorder
        for (NSView *subview in container.subviews) {
            [subview removeFromSuperview];
        }
        [container addSubview:recorderView];
        
        // Add constraints to fill the container
        [NSLayoutConstraint activateConstraints:@[
            [recorderView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [recorderView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [recorderView.topAnchor constraintEqualToAnchor:container.topAnchor],
            [recorderView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
        ]];
        
        NSLog(@"Created recorder for %@ successfully", shortcutType);
        
        // Store the recorder reference based on shortcut type
        if ([shortcutType isEqualToString:@"playPause"]) {
            self.playPauseRecorder = recorder;
        } else if ([shortcutType isEqualToString:@"previousTrack"]) {
            self.previousTrackRecorder = recorder;
        } else if ([shortcutType isEqualToString:@"nextTrack"]) {
            self.nextTrackRecorder = recorder;
        } else if ([shortcutType isEqualToString:@"skipBackward"]) {
            self.skipBackwardRecorder = recorder;
        } else if ([shortcutType isEqualToString:@"skipForward"]) {
            self.skipForwardRecorder = recorder;
        }
    } else {
        NSLog(@"Failed to create recorder for shortcut type: %@", shortcutType);
    }
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

// TODO: Replace with KeyboardShortcuts.Recorder configuration after adding KeyboardShortcuts via Xcode
/*
- (void)configureRecordView:(RecordView *)recordView withKey:(NSString *)defaultsKey {
    if (!recordView) return;
    
    // Load existing shortcut from UserDefaults
    NSData *shortcutData = [[NSUserDefaults standardUserDefaults] objectForKey:defaultsKey];
    if (shortcutData) {
        KeyCombo *keyCombo = [NSKeyedUnarchiver unarchiveObjectWithData:shortcutData];
        if (keyCombo) {
            recordView.keyCombo = keyCombo;
        }
    }
    
    // Set up callback for when shortcut changes
    __weak typeof(self) weakSelf = self;
    recordView.didChangeValueHandler = ^(RecordView *recordView) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (recordView.keyCombo) {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:recordView.keyCombo];
            [[NSUserDefaults standardUserDefaults] setObject:data forKey:defaultsKey];
        } else {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultsKey];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    };
}
*/

@end
