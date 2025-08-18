#import "VersionLabel.h"

#import "NSString+GetMediaBarVersion.h"

@implementation VersionLabel

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self != nil) {
        self.stringValue = [NSString stringWithFormat:@"Version %@", [NSString getMediaBarVersionFor:AboutVersionUseCase]];
    }
    return self;
}

@end
