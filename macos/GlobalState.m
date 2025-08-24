#import <PrivateMediaRemote/PrivateMediaRemote.h>
#import <ScriptingBridge/ScriptingBridge.h>

#import "GlobalState.h"

#import "NSData+MD5.h"

#import "Spotify.h"

#import "Constants.h"


const struct GlobalStateNotificationStruct GlobalStateNotification = {
    .infoDidChange = @"InfoDidChangeNotification",
    .isPlayingDidChange = @"IsPlayingDidChangeNotification",
};

@interface GlobalState (Private)

- (void)appDidChange:(NSNotification *)notification;
- (void)infoDidChange:(NSNotification *)notification;
- (void)isPlayingDidChange:(NSNotification *)notification;

- (void)getNowPlayingInfo;

// Media-control integration methods
- (void)startMediaControlStream;
- (void)getInitialMediaState;
- (void)mediaControlDataAvailable:(NSNotification *)notification;
- (void)processMediaControlOutput:(NSString *)output;
- (void)updateFromMediaControlData:(NSDictionary *)payload;
- (void)debugLog:(NSString *)message;
- (void)restartMediaControlStream;

@end

static void commonInit(GlobalState *self) {
    NSLog(@"🚀 Starting media-control integration (macOS 15+ compatible)...");
    
    // Start media-control stream process for event-driven notifications
    [self startMediaControlStream];
    
    // Get initial state asynchronously to avoid blocking app startup
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self getInitialMediaState];
    });
    
    // Trigger initial display with empty state
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:GlobalStateNotification.infoDidChange object:nil];
    });
}

@implementation GlobalState {
    SpotifyApplication * _Nullable spotifyApp;
    SBApplication * _Nullable tidalApp;
    NSTask * _Nullable mediaControlTask;
    NSPipe * _Nullable mediaControlPipe;
    NSFileHandle * _Nullable mediaControlFileHandle;
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
            NSLog(@"📱 MediaRemote callback received with info: ❌ No data");
            self.artist = nil;
            self.title = nil;
            self.album = nil;
            self.albumArtwork = nil;
            self.albumArtworkChecksum = nil;
            self.timestamp = nil;
            self.duration = 0;
            self->_elapsedTime = 0;
        } else {
            NSString *artist = [info objectForKey:kMRMediaRemoteNowPlayingInfoArtist];
            NSString *title = [info objectForKey:kMRMediaRemoteNowPlayingInfoTitle];
            NSLog(@"🎼 MediaRemote callback received - Artist: %@, Title: %@", artist ?: @"(none)", title ?: @"(none)");
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
    
    // Clean up media-control streams
    if (mediaControlTask) {
        [mediaControlTask terminate];
        mediaControlTask = nil;
    }
    
    if (mediaControlFileHandle) {
        [mediaControlFileHandle closeFile];
        mediaControlFileHandle = nil;
    }
    
    mediaControlPipe = nil;
}

#pragma mark - Notification handlers

- (void)isPlayingDidChange:(NSNotification *)notification {
    NSLog(@"🎵 isPlayingDidChange notification received!");
    self.isPlaying = [[notification.userInfo objectForKey:kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey] boolValue];
    NSLog(@"▶️ Playing state changed to: %@", self.isPlaying ? @"PLAYING" : @"PAUSED");
    
    [NSNotificationCenter.defaultCenter postNotificationName:GlobalStateNotification.isPlayingDidChange object:nil];
    
    [self getNowPlayingInfo];
}

- (void)infoDidChange:(NSNotification *)notification {
    NSLog(@"📀 infoDidChange notification received!");
    [self getNowPlayingInfo];
}

- (void)appDidChange:(NSNotification *)notification {
    NSLog(@"📱 appDidChange notification received!");
    [self getNowPlayingInfo];
}

#pragma mark - Media Control Integration

- (void)startMediaControlStream {
    [self debugLog:@"=== STARTING MEDIA STREAM ==="];
    NSLog(@"📡 Starting media-control stream for event-driven notifications...");
    
    // Create task to run media-control stream
    mediaControlTask = [[NSTask alloc] init];
    mediaControlTask.launchPath = @"/opt/homebrew/bin/media-control";
    mediaControlTask.arguments = @[@"stream", @"--no-diff"];
    
    // Set up environment variables for media-control stream
    NSMutableDictionary *environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    environment[@"PATH"] = @"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
    environment[@"DYLD_FRAMEWORK_PATH"] = @"/opt/homebrew/Frameworks";
    mediaControlTask.environment = environment;
    NSLog(@"🔧 Set environment PATH for stream: %@", environment[@"PATH"]);
    
    // Set up pipe to read output
    mediaControlPipe = [NSPipe pipe];
    mediaControlTask.standardOutput = mediaControlPipe;
    mediaControlTask.standardError = [NSPipe pipe]; // Discard errors
    
    // Get file handle for reading
    mediaControlFileHandle = [mediaControlPipe fileHandleForReading];
    
    // Set up notification for data availability
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mediaControlDataAvailable:)
                                                 name:NSFileHandleReadCompletionNotification
                                               object:mediaControlFileHandle];
    
    // Start reading in background
    [mediaControlFileHandle readInBackgroundAndNotify];
    
    // Launch the task
    @try {
        [mediaControlTask launch];
        NSLog(@"✅ media-control stream started successfully");
    } @catch (NSException *exception) {
        NSLog(@"❌ Failed to start media-control: %@", exception.reason);
    }
}

- (void)mediaControlDataAvailable:(NSNotification *)notification {
    NSData *data = notification.userInfo[NSFileHandleNotificationDataItem];
    
    if (data.length > 0) {
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [self processMediaControlOutput:output];
        
        // Continue reading
        [mediaControlFileHandle readInBackgroundAndNotify];
    } else {
        NSLog(@"⚠️ media-control stream ended");
        [self restartMediaControlStream];
    }
}

- (void)processMediaControlOutput:(NSString *)output {
    // Initialize buffer if needed
    if (!self.mediaControlBuffer) {
        self.mediaControlBuffer = [[NSMutableString alloc] init];
    }
    
    // Append new output to buffer
    [self.mediaControlBuffer appendString:output];
    
    // Process complete JSON objects from buffer
    NSRange searchRange = NSMakeRange(0, self.mediaControlBuffer.length);
    while (searchRange.location < self.mediaControlBuffer.length) {
        // Find next complete JSON object (looks for newline)
        NSRange newlineRange = [self.mediaControlBuffer rangeOfString:@"\n" options:0 range:searchRange];
        if (newlineRange.location == NSNotFound) {
            // No complete line yet, wait for more data
            break;
        }
        
        // Extract complete line
        NSRange lineRange = NSMakeRange(searchRange.location, newlineRange.location - searchRange.location);
        NSString *line = [self.mediaControlBuffer substringWithRange:lineRange];
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (trimmedLine.length > 0) {
            @try {
                NSData *jsonData = [trimmedLine dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
                
                if (json && [json[@"type"] isEqualToString:@"data"]) {
                    [self debugLog:[NSString stringWithFormat:@"Processing complete JSON object (length: %lu)", (unsigned long)trimmedLine.length]];
                    [self updateFromMediaControlData:json[@"payload"]];
                } else {
                    [self debugLog:[NSString stringWithFormat:@"Ignoring non-data JSON: %@", json[@"type"] ?: @"(no type)"]];
                }
            } @catch (NSException *exception) {
                NSLog(@"⚠️ Failed to parse media-control JSON: %@", exception.reason);
                [self debugLog:[NSString stringWithFormat:@"JSON parse failed: %@", exception.reason]];
            }
        }
        
        // Move to next line
        searchRange.location = newlineRange.location + newlineRange.length;
    }
    
    // Remove processed data from buffer
    if (searchRange.location > 0) {
        NSString *remaining = [self.mediaControlBuffer substringFromIndex:searchRange.location];
        [self.mediaControlBuffer setString:remaining];
        [self debugLog:[NSString stringWithFormat:@"Buffer trimmed, remaining: %lu chars", (unsigned long)remaining.length]];
    }
}

- (void)updateFromMediaControlData:(NSDictionary *)payload {
    if (!payload || [payload count] == 0) return;
    
    // File-based debug logging
    [self debugLog:[NSString stringWithFormat:@"=== PAYLOAD RECEIVED ==="]];
    [self debugLog:[NSString stringWithFormat:@"Keys: %@", [payload.allKeys componentsJoinedByString:@", "]]];
    if (payload[@"title"]) [self debugLog:[NSString stringWithFormat:@"Title: %@", payload[@"title"]]];
    if (payload[@"artist"]) [self debugLog:[NSString stringWithFormat:@"Artist: %@", payload[@"artist"]]];
    if (payload[@"playing"]) [self debugLog:[NSString stringWithFormat:@"Playing: %@", payload[@"playing"]]];
    if (payload[@"artworkMimeType"]) [self debugLog:[NSString stringWithFormat:@"ArtworkMimeType: %@", payload[@"artworkMimeType"]]];
    if (payload[@"artworkData"]) {
        NSString *artworkData = payload[@"artworkData"];
        [self debugLog:[NSString stringWithFormat:@"ArtworkData length: %lu chars", (unsigned long)artworkData.length]];
        [self debugLog:[NSString stringWithFormat:@"ArtworkData preview: %@...", [artworkData substringToIndex:MIN(50, artworkData.length)]]];
    } else {
        [self debugLog:@"ArtworkData: MISSING"];
    }
    
    // Debug: Show all keys in payload
    NSLog(@"🔍 [DEBUG] Received payload keys: %@", [payload.allKeys componentsJoinedByString:@", "]);
    
    BOOL didChange = NO;
    BOOL titleDidChange = NO;
    
    // Check if this looks like a complete song change payload
    // Complete payloads typically have title and other metadata keys present
    BOOL hasTitle = [payload.allKeys containsObject:@"title"];
    BOOL hasArtist = [payload.allKeys containsObject:@"artist"];
    BOOL hasAlbum = [payload.allKeys containsObject:@"album"];
    
    // Consider it a complete song update if we have title + at least one other metadata field
    // OR if we have just a title but it's different from current (song change)
    BOOL isCompleteUpdate = (hasTitle && (hasArtist || hasAlbum)) ||
                           (hasTitle && payload[@"title"] != nil && ![payload[@"title"] isEqualToString:self.title]);
    
#ifdef DEBUG
    NSLog(@"📊 Payload analysis - title:%@ artist:%@ album:%@ -> complete update: %@", 
          hasTitle ? @"YES" : @"NO", hasArtist ? @"YES" : @"NO", hasAlbum ? @"YES" : @"NO",
          isCompleteUpdate ? @"YES" : @"NO");
#endif
    
    // Update playing state (always process)
    if (payload[@"playing"] != nil) {
        BOOL newPlaying = [payload[@"playing"] boolValue];
        if (self.isPlaying != newPlaying) {
            NSLog(@"🎵 Playing state changed: %@ -> %@", 
                  self.isPlaying ? @"playing" : @"paused",
                  newPlaying ? @"playing" : @"paused");
            self.isPlaying = newPlaying;
            didChange = YES;
            
#ifdef DEBUG
            NSLog(@"🔍 [DEBUG] Play state change will trigger UI update");
#endif
            
            // Post playing state change notification
            [NSNotificationCenter.defaultCenter postNotificationName:GlobalStateNotification.isPlayingDidChange object:nil];
        }
    }
    
    // Only update track info for complete updates to avoid flashing
    if (isCompleteUpdate) {
        // Update title - always present in complete updates
        if (hasTitle) {
            NSString *newTitle = payload[@"title"]; // Can be nil or actual value
            // Check for title change BEFORE updating self.title
            titleDidChange = ![self.title isEqualToString:newTitle];
            if (titleDidChange) {
                NSLog(@"🎼 Title changed: %@ -> %@", self.title ?: @"(none)", newTitle ?: @"(none)");
                self.title = newTitle;
                didChange = YES;
            }
        }
        
        // Update artist - clear if not present or empty in complete update
        NSString *newArtist = nil;
        if (hasArtist) {
            newArtist = payload[@"artist"];
            // Treat empty strings as nil for cleaner display
            if (newArtist && [newArtist length] == 0) {
                newArtist = nil;
            }
        }
        if (![self.artist isEqualToString:newArtist]) {
            NSLog(@"👤 Artist changed: %@ -> %@", self.artist ?: @"(none)", newArtist ?: @"(none)");
            self.artist = newArtist;
            didChange = YES;
        }
        
        // Update album - clear if not present or empty in complete update
        NSString *newAlbum = nil;
        if (hasAlbum) {
            newAlbum = payload[@"album"];
            // Treat empty strings as nil for cleaner display
            if (newAlbum && [newAlbum length] == 0) {
                newAlbum = nil;
            }
        }
        if (![self.album isEqualToString:newAlbum]) {
            NSLog(@"💿 Album changed: %@ -> %@", self.album ?: @"(none)", newAlbum ?: @"(none)");
            self.album = newAlbum;
            didChange = YES;
        }
    } else {
#ifdef DEBUG
        NSLog(@"⏭️ Skipping track info update - incomplete payload");
#endif
    }
    
    // Update timing info
    if (payload[@"elapsedTime"] != nil) {
        double newElapsedTime = [payload[@"elapsedTime"] doubleValue];
        self->_elapsedTime = newElapsedTime;
    }
    
    if (payload[@"duration"] != nil) {
        double newDuration = [payload[@"duration"] doubleValue];
        self.duration = newDuration;
    }
    
    if (payload[@"timestamp"] != nil) {
        // Parse ISO 8601 timestamp
        NSString *timestampString = payload[@"timestamp"];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        self.timestamp = [formatter dateFromString:timestampString];
    }
    
    // Handle artwork from media-control payload (primary source)
    [self debugLog:@"=== ARTWORK PROCESSING ==="];
    if (payload[@"artworkData"] != nil) {
        NSString *base64ArtworkData = payload[@"artworkData"];
        [self debugLog:[NSString stringWithFormat:@"artworkData present, length: %lu", (unsigned long)[base64ArtworkData length]]];
        NSLog(@"🎨 [ARTWORK DEBUG] artworkData present, length: %lu", (unsigned long)[base64ArtworkData length]);
        
        if (base64ArtworkData && [base64ArtworkData length] > 0) {
            NSData *artworkData = [[NSData alloc] initWithBase64EncodedString:base64ArtworkData options:NSDataBase64DecodingIgnoreUnknownCharacters];
            [self debugLog:[NSString stringWithFormat:@"Base64 decode result: %@ (length: %lu)", artworkData ? @"SUCCESS" : @"FAILED", (unsigned long)artworkData.length]];
            NSLog(@"🎨 [ARTWORK DEBUG] Base64 decode result: %@ (length: %lu)", artworkData ? @"SUCCESS" : @"FAILED", (unsigned long)artworkData.length);
            
            if (artworkData) {
                NSString *newArtworkChecksum = [artworkData MD5];
                [self debugLog:[NSString stringWithFormat:@"New checksum: %@", newArtworkChecksum]];
                [self debugLog:[NSString stringWithFormat:@"Current checksum: %@", self.albumArtworkChecksum ?: @"(nil)"]];
                NSLog(@"🎨 [ARTWORK DEBUG] New checksum: %@, Current checksum: %@", newArtworkChecksum, self.albumArtworkChecksum);
                
                NSString *trackInfo = [NSString stringWithFormat:@"'%@ - %@'", 
                                      payload[@"artist"] ?: @"Unknown Artist", 
                                      payload[@"title"] ?: @"Unknown Title"];
                
                if (![self.albumArtworkChecksum isEqualToString:newArtworkChecksum]) {
                    [self debugLog:[NSString stringWithFormat:@"*** ARTWORK UPDATE *** Track: %@ - New artwork detected (checksum changed)", trackInfo]];
                    [self debugLog:[NSString stringWithFormat:@"Previous checksum: %@", self.albumArtworkChecksum ?: @"(none)"]];
                    [self debugLog:[NSString stringWithFormat:@"New checksum: %@", newArtworkChecksum]];
                    NSLog(@"🖼️ Updating album artwork from media-control artworkData");
                    NSImage *newImage = [[NSImage alloc] initWithData:artworkData];
                    [self debugLog:[NSString stringWithFormat:@"NSImage creation: %@ (size: %.0fx%.0f)", 
                                   newImage ? @"SUCCESS" : @"FAILED", 
                                   newImage ? newImage.size.width : 0, 
                                   newImage ? newImage.size.height : 0]];
                    NSLog(@"🎨 [ARTWORK DEBUG] NSImage creation result: %@ (size: %.0fx%.0f)", 
                          newImage ? @"SUCCESS" : @"FAILED", 
                          newImage ? newImage.size.width : 0, 
                          newImage ? newImage.size.height : 0);
                    
                    self.albumArtwork = newImage;
                    self.albumArtworkChecksum = newArtworkChecksum;
                    didChange = YES;
                    [self debugLog:@"*** ARTWORK UPDATED SUCCESSFULLY *** - didChange = YES"];
                } else {
                    [self debugLog:[NSString stringWithFormat:@"*** ARTWORK UNCHANGED *** Track: %@ - Same artwork as previous track (checksum: %@)", trackInfo, newArtworkChecksum]];
                    [self debugLog:@"This is NORMAL behavior when multiple tracks share the same album artwork"];
                    NSLog(@"🎨 [ARTWORK DEBUG] Checksum unchanged, skipping artwork update for track: %@", trackInfo);
                }
            } else {
                [self debugLog:@"CRITICAL: Failed to decode base64 artwork data"];
                NSLog(@"🎨 [ARTWORK DEBUG] Failed to decode base64 artwork data");
            }
        } else {
            [self debugLog:@"Empty or nil artworkData"];
            NSLog(@"🎨 [ARTWORK DEBUG] Empty or nil artworkData");
            // Empty artworkData means no artwork
            if (self.albumArtwork != nil) {
                [self debugLog:@"Clearing album artwork (empty artworkData)"];
                NSLog(@"🖼️ Clearing album artwork (empty artworkData)");
                self.albumArtwork = nil;
                self.albumArtworkChecksum = nil;
                didChange = YES;
            }
        }
    } else {
        [self debugLog:@"No artworkData key in payload"];
        
        // If this is a complete song update but no artwork, clear the old artwork
        // to prevent showing previous song's artwork with new song metadata
        if (isCompleteUpdate && titleDidChange && self.albumArtwork != nil) {
            [self debugLog:[NSString stringWithFormat:@"Song changed to '%@' but no artwork in message - clearing old artwork to prevent mismatch", 
                           self.title ?: @"(none)"]];
            self.albumArtwork = nil;
            self.albumArtworkChecksum = nil;
            didChange = YES;
        } else if (isCompleteUpdate && !titleDidChange) {
            [self debugLog:@"Complete update but same song title - keeping existing artwork"];
        } else if (isCompleteUpdate && titleDidChange) {
            [self debugLog:@"Song changed but no existing artwork to clear"];
        }
        
        // Stream will deliver artwork in subsequent messages
        [self debugLog:@"No artworkData in this message - artwork will arrive in subsequent stream messages"];
    }
    
    // Post info change notification if anything changed
    [self debugLog:[NSString stringWithFormat:@"=== FINAL STATE ==="]];
    [self debugLog:[NSString stringWithFormat:@"didChange: %@", didChange ? @"YES" : @"NO"]];
    [self debugLog:[NSString stringWithFormat:@"Current artwork: %@", self.albumArtwork ? @"PRESENT" : @"NIL"]];
    [self debugLog:[NSString stringWithFormat:@"Current checksum: %@", self.albumArtworkChecksum ?: @"(nil)"]];
    
    if (didChange) {
        [self debugLog:@"Posting GlobalStateNotification.infoDidChange"];
        [NSNotificationCenter.defaultCenter postNotificationName:GlobalStateNotification.infoDidChange object:nil];
    } else {
        [self debugLog:@"No changes detected, skipping notification"];
    }
}

- (void)getInitialMediaState {
    NSLog(@"🔍 Getting initial media state from media-control...");
    
    // Run media-control get to get current state
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/opt/homebrew/bin/media-control";
    task.arguments = @[@"get"];
    
    // Set up environment variables for media-control
    NSMutableDictionary *environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    environment[@"PATH"] = @"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
    environment[@"DYLD_FRAMEWORK_PATH"] = @"/opt/homebrew/Frameworks";
    task.environment = environment;
    NSLog(@"🔧 Set environment PATH: %@", environment[@"PATH"]);
    
    NSPipe *stdoutPipe = [NSPipe pipe];
    NSPipe *stderrPipe = [NSPipe pipe];
    task.standardOutput = stdoutPipe;
    task.standardError = stderrPipe;
    
    @try {
        NSLog(@"🚀 Launching media-control task...");
        [task launch];
        NSLog(@"⏳ Waiting for media-control task to complete...");
        [task waitUntilExit];
        NSLog(@"✅ media-control task completed with exit code: %d", [task terminationStatus]);
    } @catch (NSException *exception) {
        NSLog(@"❌ Failed to launch media-control task: %@", exception.reason);
        return;
    }
    
    // Try stdout first
    NSData *stdoutData = [[stdoutPipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding];
    
    // If stdout is empty, check stderr (media-control sometimes outputs JSON to stderr)
    if (output.length == 0) {
        NSData *stderrData = [[stderrPipe fileHandleForReading] readDataToEndOfFile];
        output = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];
        NSLog(@"📱 Got media state from stderr: %@", output);
    }
    
    if (output.length > 0) {
        NSLog(@"📱 Got initial media output (length %lu): %@", (unsigned long)output.length, [output substringToIndex:MIN(200, output.length)]);
        @try {
            NSData *jsonData = [output dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            
            if (json) {
                NSLog(@"📱 Initial media state parsed successfully: %@", json);
                [self updateFromMediaControlData:json];
                NSLog(@"📱 Called updateFromMediaControlData with initial state");
            } else {
                NSLog(@"⚠️ Failed to parse JSON from output: %@", output);
            }
        } @catch (NSException *exception) {
            NSLog(@"⚠️ Failed to parse initial state JSON: %@", exception.reason);
        }
    } else {
        NSLog(@"ℹ️ No initial media state available (empty output)");
    }
}

- (void)restartMediaControlStream {
    [self debugLog:@"=== RESTARTING MEDIA STREAM ==="];
    NSLog(@"🔄 Restarting media-control stream...");
    
    // Clean up existing task
    if (mediaControlTask) {
        [mediaControlTask terminate];
        mediaControlTask = nil;
    }
    
    if (mediaControlFileHandle) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSFileHandleReadCompletionNotification
                                                      object:mediaControlFileHandle];
        [mediaControlFileHandle closeFile];
        mediaControlFileHandle = nil;
    }
    
    mediaControlPipe = nil;
    
    // Restart after a delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startMediaControlStream];
    });
}

- (void)debugLog:(NSString *)message {
    NSString *timestampedMessage = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], message];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:@"/tmp/mediabar-debug.log"];
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[timestampedMessage dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    } else {
        // Create file if it doesn't exist
        [timestampedMessage writeToFile:@"/tmp/mediabar-debug.log" atomically:NO encoding:NSUTF8StringEncoding error:nil];
    }
}


#pragma mark - Actions


- (double)getElapsedTime {
    double elapsedTimeAtTimestamp = self.elapsedTime;
    
    return self.isPlaying ? elapsedTimeAtTimestamp + [NSDate.date timeIntervalSinceDate:self.timestamp] : elapsedTimeAtTimestamp;
}

- (void)togglePlayPause {
//    NSLog(@"togglePlayPause");
    MRMediaRemoteSendCommand(MRMediaRemoteCommandTogglePlayPause, nil);
}

- (void)previous {
    MRMediaRemoteSendCommand(MRMediaRemoteCommandPreviousTrack, nil);
//    NSLog(@"global previous");
}


- (void)next {
    MRMediaRemoteSendCommand(MRMediaRemoteCommandNextTrack, nil);
//    NSLog(@"global next");
}

- (void)skipBackward {
//    double myElapsedTime = [self getElapsedTime];
//    NSLog(@"myElapsedTime: %lf", myElapsedTime);
//    NSLog(@"stepBackwardDuration: %ld", _skipBackwardDuration);
    

    MRMediaRemoteSetElapsedTime([self getElapsedTime] - _skipBackwardDuration);
//    MRMediaRemoteSetElapsedTime([self getElapsedTime] - [self.userDefaults integerForKey:StepBackwardDurationUserDefaultsKey]);

//    NSLog(@"global skipBackward");
}

- (void)skipForward {
//    double myElapsedTime = [self getElapsedTime];
//    NSLog(@"myElapsedTime: %lf", myElapsedTime);
    
//    NSLog(@"stepForwardDuration: %ld", _skipForwardDuration);
    MRMediaRemoteSetElapsedTime([self getElapsedTime] + _skipForwardDuration);
    
//    MRMediaRemoteSetElapsedTime([self getElapsedTime] + 10);
//    NSLog(@"global skipForward");
}

- (void)setElapsedTime:(double)elapsedTime {
    _elapsedTime = elapsedTime;
    MRMediaRemoteSetElapsedTime(elapsedTime);
}

@end
