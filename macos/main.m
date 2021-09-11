@import Cocoa;

#import "Constants.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        __block BOOL shouldSend = NO;

        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
        [userDefaults registerDefaults:[NSDictionary dictionaryWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"DefaultPreferences" withExtension:@"plist"]]];
        
        void (^updateShouldSend)(NSNotification *)  = ^(NSNotification *notification) {
            if (notification != nil && notification.object == NSUserDefaults.standardUserDefaults) return;
            shouldSend = [[userDefaults objectForKey:EnableErrorReportingUserDefaultsKey] boolValue];
        };
        
        updateShouldSend(nil);
        
        [NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification
                                                        object:nil
                                                         queue:nil
                                                    usingBlock:updateShouldSend];
    }
    return NSApplicationMain(argc, argv);
}
