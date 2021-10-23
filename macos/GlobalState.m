#import <PrivateMediaRemote/PrivateMediaRemote.h>
#import <ScriptingBridge/ScriptingBridge.h>

#import "GlobalState.h"

#import "NSData+MD5.h"

#import "Spotify.h"

#import "Constants.h"

#if __MAC_OS_X_VERSION_MIN_REQUIRED <= __MAC_10_14
enum {
    errAEEventWouldRequireUserConsent = -1744,
};
#endif

const struct GlobalStateNotificationStruct GlobalStateNotification = {
    .infoDidChange = @"InfoDidChangeNotification",
    .isPlayingDidChange = @"IsPlayingDidChangeNotification",
};

@interface GlobalState (Private)

- (void)appDidChange:(NSNotification *)notification;
- (void)infoDidChange:(NSNotification *)notification;
- (void)isPlayingDidChange:(NSNotification *)notification;

- (void)getNowPlayingInfo;

@end

static void commonInit(GlobalState *self) {
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appDidChange:)
                                               name:kMRMediaRemoteNowPlayingApplicationDidChangeNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(infoDidChange:)
                                               name:kMRMediaRemoteNowPlayingInfoDidChangeNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(isPlayingDidChange:)
                                               name:kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification
                                             object:nil];
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    MRMediaRemoteRegisterForNowPlayingNotifications(queue);
    
    MRMediaRemoteGetNowPlayingApplicationIsPlaying(queue, ^(BOOL isPlaying) {
        self.isPlaying = isPlaying;
    });

    [self getNowPlayingInfo];
}

@implementation GlobalState {
    SpotifyApplication * _Nullable spotifyApp;
    SBApplication * _Nullable tidalApp;
}

- (NSImage * _Nullable)getAlbumArtworkFromSpotify {
    if (spotifyApp == nil) {
        if (@available(macOS 10.14, *)) {
            NSAppleEventDescriptor *targetAppEventDescriptor = [NSAppleEventDescriptor descriptorWithBundleIdentifier:spotifyBundleIdentifier];
            OSStatus error = AEDeterminePermissionToAutomateTarget([targetAppEventDescriptor aeDesc], typeWildCard, typeWildCard, YES);
            
            if (error == errAEEventWouldRequireUserConsent || error == errAEEventNotPermitted) {
                return spotifyRequestPermissionsAlbumArtwork;
            }
        }
        spotifyApp = (id)[[SBApplication alloc] initWithBundleIdentifier:spotifyBundleIdentifier];
        if (spotifyApp == nil) return nil;
    }
    SpotifyTrack *track = spotifyApp.currentTrack;
    return track.artworkUrl == nil ? nil : [[NSImage alloc] initWithContentsOfURL:[[NSURL alloc] initWithString:track.artworkUrl]];
}

- (void)getNowPlayingInfo {
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(NSDictionary *info) {
        if (info == nil) {
            self.artist = nil;
            self.title = nil;
            self.album = nil;
            self.albumArtwork = nil;
            self.albumArtworkChecksum = nil;
            self.timestamp = nil;
            self.duration = 0;
            self->_elapsedTime = 0;
        } else {
            self.artist = [info objectForKey:kMRMediaRemoteNowPlayingInfoArtist];
            self.title = [info objectForKey:kMRMediaRemoteNowPlayingInfoTitle];
            self.album = [info objectForKey:kMRMediaRemoteNowPlayingInfoAlbum];

            _MRNowPlayingClientProtobuf *client = [[_MRNowPlayingClientProtobuf alloc] initWithData:[info objectForKey:kMRMediaRemoteNowPlayingInfoClientPropertiesData]];
            BOOL isSpotify = [client.bundleIdentifier isEqualToString:spotifyBundleIdentifier];
            NSData *mediaRemoteArtwork = [info objectForKey:kMRMediaRemoteNowPlayingInfoArtworkData];
            NSString *albumArtworkChecksum = mediaRemoteArtwork == nil ? nil : [mediaRemoteArtwork MD5];
            if (self.albumArtworkChecksum != albumArtworkChecksum || isSpotify) {
                self.albumArtwork = (mediaRemoteArtwork == nil && !isSpotify) ? nil : isSpotify
                    ? [self getAlbumArtworkFromSpotify]
                    : [[NSImage alloc] initWithData:mediaRemoteArtwork];
                self.albumArtworkChecksum = isSpotify ? [self.albumArtwork TIFFRepresentation].MD5 : albumArtworkChecksum;
            }

            self.timestamp = [info objectForKey:kMRMediaRemoteNowPlayingInfoTimestamp];
            NSNumber *duration = [info objectForKey:kMRMediaRemoteNowPlayingInfoDuration];
            self.duration = duration == nil ? 0 : duration.doubleValue;
            self->_elapsedTime = [[info objectForKey:kMRMediaRemoteNowPlayingInfoElapsedTime] doubleValue];
        }
        
        [NSNotificationCenter.defaultCenter postNotificationName:GlobalStateNotification.infoDidChange object:nil];
    });
}


#pragma mark - NSObject methods

- (instancetype)init {
    self = [super init];
//    if (self) commonInit(self);
    if (self) {
        NSLog(@"global state saw self");
        commonInit(self);
    } else {
        NSLog(@"global state didn't see self");
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    MRMediaRemoteUnregisterForNowPlayingNotifications();
}

#pragma mark - Notification handlers

- (void)isPlayingDidChange:(NSNotification *)notification {
    self.isPlaying = [[notification.userInfo objectForKey:kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey] boolValue];
    
    [NSNotificationCenter.defaultCenter postNotificationName:GlobalStateNotification.isPlayingDidChange object:nil];
    
    [self getNowPlayingInfo];
}

- (void)infoDidChange:(NSNotification *)notification {
    [self getNowPlayingInfo];
}

- (void)appDidChange:(NSNotification *)notification {
    [self getNowPlayingInfo];
}

#pragma mark - Actions


- (double)getElapsedTime {
    double TESTelapsedTimeAtTimestamp = self.elapsedTime;
    
    return self.isPlaying ? TESTelapsedTimeAtTimestamp + [NSDate.date timeIntervalSinceDate:self.timestamp] : TESTelapsedTimeAtTimestamp;
}

- (void)togglePlayPause {
    NSLog(@"togglePlayPause");
    MRMediaRemoteSendCommand(MRMediaRemoteCommandTogglePlayPause, nil);
}

- (void)previous {
    MRMediaRemoteSendCommand(MRMediaRemoteCommandPreviousTrack, nil);
//    MRMediaRemoteSendCommand(MRMediaRemoteCommandRewind15Seconds, nil);
    NSLog(@"global previous");
}

- (void)skipBackward {
    NSLog(@"self.elapsedTime: %lf", self.elapsedTime);
    
//    double TESTelapsedTimeAtTimestamp = self.elapsedTime;
//    double TESTelapsedTime = self.isPlaying ? TESTelapsedTimeAtTimestamp + [NSDate.date timeIntervalSinceDate:self.timestamp] : TESTelapsedTimeAtTimestamp;
    
    double myElapsedTime = [self getElapsedTime];
    
    NSLog(@"myElapsedTime: %lf", myElapsedTime);
    
//    [self getNowPlayingInfo];
//    self.elapsedTime = self.elapsedTime - 10;
    MRMediaRemoteSetElapsedTime(myElapsedTime - 10);
//    NSLog(@"(after skip) self.elapsedTime: %lf", self.elapsedTime);
//    [self getNowPlayingInfo];
//    NSLog(@"(after getting info) self.elapsedTime: %lf", self.elapsedTime);
    NSLog(@"global skipBackward");
}

- (void)skipForward {
//    NSLog(@"self.globalState.elapsedTime: %lf", self.elapsedTime);
    
    double myElapsedTime = [self getElapsedTime];
    NSLog(@"myElapsedTime: %lf", myElapsedTime);
    
    MRMediaRemoteSetElapsedTime(myElapsedTime + 10);
    NSLog(@"global skipForward");
}


- (void)next {
    MRMediaRemoteSendCommand(MRMediaRemoteCommandNextTrack, nil);
}

- (void)setElapsedTime:(double)elapsedTime {
    _elapsedTime = elapsedTime;
    MRMediaRemoteSetElapsedTime(elapsedTime);
}

@end
