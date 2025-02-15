#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const struct GlobalStateNotificationStruct {
    NSString * _Nonnull infoDidChange;
    NSString * _Nonnull isPlayingDidChange;
} GlobalStateNotification;

@interface GlobalState : NSObject

@property BOOL isPlaying;
@property (nullable) NSString *title;
@property (nullable) NSString *artist;
@property (nullable) NSString *album;
@property (nullable) NSImage *albumArtwork;
@property (nullable) NSString *albumArtworkChecksum;
@property (nullable) NSDate *timestamp;
@property double duration;
@property (nonatomic) double elapsedTime;
@property NSInteger skipBackwardDuration;
@property NSInteger skipForwardDuration;

#pragma mark - Actions

- (double)getElapsedTime;
- (void)togglePlayPause;
- (void)previous;
- (void)skipBackward;
- (void)skipForward;
- (void)next;

@end

NS_ASSUME_NONNULL_END
