// @import DNLoginServiceKit;  // Temporarily disabled

#import "LaunchAtLoginViewController.h"

#import "Constants.h"

@interface LaunchAtLoginViewController ()

@end

@implementation LaunchAtLoginViewController

- (IBAction)enableLaunchAtLoginAction:(NSButton *)sender {
    // [DNLoginServiceKit addLoginItem];  // Temporarily disabled
    [self nextAction:sender];
}

- (IBAction)nextAction:(id)sender {
    [NSNotificationCenter.defaultCenter postNotificationName:SetupCompletedNotificationName object:nil];
}

@end
