#import <QuartzCore/QuartzCore.h>

#import "PopoverViewController.h"

#import "NSImage+ProportionalScaling.h"
#import "NSString+FormatTime.h"

#import "GlobalState.h"


static NSImage *playImage = [NSImage imageNamed:@"Play"];
static NSImage *pauseImage = [NSImage imageNamed:@"Pause"];
static NSSize albumArtworkSize = NSMakeSize(300, 300);

@interface PopoverViewController ()

@property (weak) IBOutlet GlobalState *globalState;

@property (weak) IBOutlet NSPopover *popover;

@property (weak) IBOutlet NSView *albumArtwork;
@property (weak) IBOutlet NSView *maskedAlbumArtwork;
@property (strong) IBOutlet NSString *albumArtworkChecksum;

@property (weak) IBOutlet NSView *progressBackground;

@property (weak) IBOutlet NSButton *playPauseButton;

@property (weak) IBOutlet NSTextField *elapsedTimeLabel;
@property (weak) IBOutlet NSTextField *durationRemainingTimeLabel;

@property (weak) IBOutlet NSView *progress;
@property (weak) IBOutlet NSLayoutConstraint *progressWidthConstraint;
@property (weak) IBOutlet NSView *thumb;

@property NSTimer *timer;

@property BOOL showRemainingTime;

@end

@implementation PopoverViewController

- (BOOL)canBecomeFirstResponder {
    return YES;
}

//- (NSArray<UIKeyCommand *>*)keyCommands {
//    return @[
//        [UIKeyCommand keyCommandWithInput:@"1" modifierFlags:UIKeyModifierCommand action:@selector(selectTab:) discoverabilityTitle:@"Types"],
//
//        [UIKeyCommand keyCommandWithInput:@"f"
//                            modifierFlags:UIKeyModifierCommand | UIKeyModifierAlternate
//                                   action:@selector(search:)
//                     discoverabilityTitle:@"Find…"]
//    ];
//}

- (void)handleTickWithElapsedTime:(double)elapsedTime {
    double duration = self.globalState.duration;
    if (duration == 0) {
        self.elapsedTimeLabel.stringValue = @"0:00";
        self.durationRemainingTimeLabel.stringValue = self.showRemainingTime ? @"-0:00" : @"0:00";
        self.progressWidthConstraint.constant = 0;
        return;
    }
    
    self.elapsedTimeLabel.stringValue = [NSString formatSeconds:elapsedTime];
    
//    self.elapsedTimeLabel.stringValue = [NSString stringWithFormat:@"%d:%02d", minutes, seconds];;
//    stringWithFormat:@"%d:%02d"
    
    self.progressWidthConstraint.constant = self.progress.superview.bounds.size.width * (elapsedTime / duration);

    if (self.showRemainingTime) {
        NSString *formattedTime = [NSString formatSeconds:duration - elapsedTime];
        self.durationRemainingTimeLabel.stringValue = [NSString stringWithFormat:@"-%@", formattedTime];
    }
}

- (void)handleTick {
    if (self.globalState.timestamp == nil) return;

//    double elapsedTimeAtTimestamp = self.globalState.elapsedTime;
//    double elapsedTime = self.globalState.isPlaying ? elapsedTimeAtTimestamp + [NSDate.date timeIntervalSinceDate:self.globalState.timestamp] : elapsedTimeAtTimestamp;
    double elapsedTime = [self.globalState getElapsedTime];
    
    [self handleTickWithElapsedTime:elapsedTime];
}

- (void)updatePopover {
    if (self.albumArtworkChecksum != self.globalState.albumArtworkChecksum) {
        NSImage *albumArtwork = [self.globalState.albumArtwork imageByScalingProportionallyToSize:albumArtworkSize];
        self.albumArtwork.layer.contents = albumArtwork;
        self.maskedAlbumArtwork.layer.contents = albumArtwork;
        self.albumArtworkChecksum = self.globalState.albumArtworkChecksum;
    }
    
    self.playPauseButton.image = self.globalState.isPlaying ? pauseImage : playImage;
    
    if (!self.showRemainingTime) {
        self.durationRemainingTimeLabel.stringValue = [NSString formatSeconds:self.globalState.duration];
    }

    [self handleTick];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - View controller

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.showRemainingTime = [NSUserDefaults.standardUserDefaults boolForKey:@"showRemainingTime"];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(stateDidChange:) name:GlobalStateNotification.infoDidChange object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(stateDidChange:) name:GlobalStateNotification.isPlayingDidChange object:nil];
    
    self.view.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;
    
    // Setting up mask
    CAGradientLayer *gradient = [[CAGradientLayer alloc] init];
    gradient.frame = self.maskedAlbumArtwork.bounds;
    id clear = (id)NSColor.clearColor.CGColor;
    id black = (id)NSColor.blackColor.CGColor;
    gradient.colors = @[clear, clear, black, black];
    gradient.locations = @[@0.0, @0.2, @0.9, @1.0];
    self.maskedAlbumArtwork.layer.mask = gradient;
    
    self.progressBackground.layer.backgroundColor = [NSColor colorWithRed:1 green:1 blue:1 alpha:0.5].CGColor;
    self.progressBackground.layer.cornerRadius = 2;
    self.progress.layer.backgroundColor = [NSColor colorWithRed:1 green:1 blue:1 alpha:0.9].CGColor;
    self.thumb.layer.backgroundColor = NSColor.whiteColor.CGColor;
    self.thumb.layer.cornerRadius = 4;
    NSShadow *thumbShadow = [[NSShadow alloc] init];
    thumbShadow.shadowOffset = NSMakeSize(0, -1);
    thumbShadow.shadowColor = [NSColor colorWithRed:0 green:0 blue:0 alpha:0.3];
    thumbShadow.shadowBlurRadius = 2.0;
    self.thumb.shadow = thumbShadow;
}

#pragma mark - Notification handlers

- (void)stateDidChange:(NSNotification *)notification {
    if (self.popover.isShown) {
        [self updatePopover];
    }
}

#pragma mark - Actions

- (IBAction)playPauseAction:(NSButton *)sender {
//    NSLog(@"self.global State object is: %@", self.globalState);
    [self.globalState togglePlayPause];
}

- (IBAction)previousAction:(NSButton *)sender {
    [self.globalState previous];
//    NSLog(@"in previousAction");
}

- (IBAction)skipBackward:(NSButton *)sender {
    [self.globalState skipBackward];
//    NSLog(@"in skipBackward");
}

- (IBAction)skipForward:(NSButton *)sender {
    [self.globalState skipForward];
//    NSLog(@"in skipForward");
}

- (IBAction)nextAction:(NSButton *)sender {
    [self.globalState next];
}

- (IBAction)durationRemainingTimeClickGestureRecognizerAction:(NSClickGestureRecognizer *)sender {
    self.showRemainingTime = !self.showRemainingTime;
    [NSUserDefaults.standardUserDefaults setBool:self.showRemainingTime forKey:@"showRemainingTime"];
    
    [self updatePopover];
}

- (IBAction)progressContainerAction:(NSControl *)sender {
    BOOL dragActive = YES;
    NSPoint location = NSZeroPoint;
    NSEvent* event = NULL;
    NSWindow *targetWindow = sender.window;
    double elapsedTime = 0;
    double duration = self.globalState.duration;
    CGFloat width = sender.bounds.size.width;
    
    @autoreleasepool {
        while (dragActive) {
            event = [targetWindow nextEventMatchingMask:(NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp)
                                              untilDate:[NSDate distantFuture]
                                                 inMode:NSEventTrackingRunLoopMode
                                                dequeue:YES];
            if (!event) continue;
            location = [sender convertPoint:event.locationInWindow fromView:nil];
            switch (event.type) {
                case NSEventTypeLeftMouseUp:
                    dragActive = NO;
                case NSEventTypeLeftMouseDragged:
                    elapsedTime = (MIN(MAX(location.x, 0), width) / width) * duration;
                    [self handleTickWithElapsedTime:elapsedTime];
                    break;
                default:
                    break;
            }
        }
    }

    self.globalState.elapsedTime = elapsedTime;
//    NSLog(@"updated self.globalState.elapsedTime");
}

#pragma mark - Popover delegate

- (void)popoverWillShow:(NSNotification *)notification {
    [self updatePopover];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(handleTick) userInfo:nil repeats:YES];
}

- (void)popoverWillClose:(NSNotification *)notification {
    [self.timer invalidate];
    self.timer = nil;
}

@end
