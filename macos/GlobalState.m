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

/**
 * MEDIABAR INITIALIZATION: Core System Bootstrap
 * ==============================================
 * 
 * Initializes MediaBar's real-time media monitoring system using media-control CLI integration.
 * This replaces legacy MediaRemote callbacks with event-driven streaming for macOS 15+ compatibility.
 * 
 * INITIALIZATION SEQUENCE:
 * 1. Start persistent media-control stream process (NSTask + NSFileHandle async reading)
 * 2. Get initial media state via synchronous media-control query
 * 3. Trigger UI update to display current state immediately
 * 
 * PERFORMANCE CONSIDERATIONS:
 * - Stream process runs continuously in background for real-time updates
 * - Initial state query happens on background queue to prevent app startup blocking  
 * - UI notification dispatched after short delay for responsive status bar appearance
 */
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
    
    // Clean up media-control streams with proper notification removal
    if (mediaControlFileHandle) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSFileHandleReadCompletionNotification
                                                      object:mediaControlFileHandle];
        [mediaControlFileHandle closeFile];
        mediaControlFileHandle = nil;
    }
    
    if (mediaControlTask) {
        [mediaControlTask terminate];
        mediaControlTask = nil;
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

/**
 * Initializes real-time media-control stream for receiving media updates and artwork data.
 * 
 * This method establishes the core integration with the media-control CLI tool that provides
 * access to macOS media information. The stream delivers JSON objects containing:
 * - Track metadata (title, artist, album, duration, etc.)
 * - Base64-encoded artwork data (can be 50KB-300KB for high-resolution album covers)
 * - Playback state and timing information
 * 
 * CRITICAL IMPLEMENTATION DETAILS:
 * 
 * 1. ENVIRONMENT VARIABLES:
 *    - PATH: Ensures media-control binary can be found and executed
 *    - DYLD_FRAMEWORK_PATH: Required for media-control to load MediaRemote frameworks
 *    - Without proper environment, stream fails silently with no media data
 * 
 * 2. STREAM ARGUMENTS:
 *    - "--no-diff": Forces delivery of complete metadata on each update
 *    - Without this flag, only changed fields are sent, breaking artwork delivery
 * 
 * 3. ASYNCHRONOUS PROCESSING:
 *    - Uses NSFileHandle readInBackgroundAndNotify for non-blocking stream reads
 *    - Large artwork data requires multiple read operations (handled by buffering)
 * 
 * The stream runs continuously until the app terminates, automatically restarting on failures.
 * Data from this stream is processed by processMediaControlOutput: which handles JSON buffering.
 */
- (void)startMediaControlStream {
    [self debugLog:@"=== STARTING MEDIA STREAM ==="];
    NSLog(@"📡 Starting media-control stream for event-driven notifications...");
    
    // Create task to run media-control stream with proper binary path
    mediaControlTask = [[NSTask alloc] init];
    mediaControlTask.launchPath = @"/opt/homebrew/bin/media-control";
    mediaControlTask.arguments = @[@"stream", @"--no-diff"];  // --no-diff ensures complete metadata delivery
    
    // CRITICAL: Set up environment variables for media-control framework loading
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

/**
 * Processes fragmented JSON data from media-control stream, implementing critical buffering for large artwork.
 * 
 * THE CORE PROBLEM SOLVED:
 * Large base64 artwork data (50KB-300KB) gets split across multiple NSFileHandle read operations.
 * Without buffering, JSON parsing fails on incomplete fragments, causing missing artwork display.
 * 
 * BUFFERING STRATEGY:
 * 1. Accumulate all incoming data in mediaControlBuffer across multiple read operations
 * 2. Search for complete JSON objects terminated by newline characters (\n)
 * 3. Process only complete objects, leaving incomplete data for the next read cycle
 * 4. Trim processed data to prevent memory accumulation
 * 
 * EXAMPLE SCENARIO:
 * Read 1: '{"type":"data","payload":{"title":"Song","artworkData":"\/9j\/4A'
 * Read 2: 'AQSkZJRgABAQAASABIAAD\/4QBMRXhpZgAATU0AKgAA..."}}\n'
 * Result: Buffer assembles complete JSON object spanning both reads for successful parsing
 * 
 * This method is called asynchronously by NSFileHandle notifications and must handle:
 * - Partial JSON objects spanning multiple reads
 * - Multiple complete JSON objects in a single read
 * - Mixed complete and partial objects in the same data chunk
 * 
 * @param output Raw string data from the media-control stream (may be incomplete JSON)
 */
- (void)processMediaControlOutput:(NSString *)output {
    // Initialize buffer for accumulating fragmented JSON data across multiple reads
    if (!self.mediaControlBuffer) {
        self.mediaControlBuffer = [[NSMutableString alloc] init];
    }
    
    // Append new data to buffer - this may complete a previously incomplete JSON object
    [self.mediaControlBuffer appendString:output];
    
    // Process complete JSON objects from buffer (search for \n-terminated objects)
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

/**
 * Processes complete media data payload from media-control stream, handling artwork and metadata updates.
 * 
 * This method implements the core artwork processing pipeline and two-phase delivery pattern recognition.
 * 
 * TWO-PHASE DELIVERY PATTERN:
 * Many media systems deliver metadata and artwork in separate messages:
 * 1. First message: Contains track info (title, artist, album) but no artworkData
 * 2. Second message: Contains same track info plus base64 artworkData
 * 
 * ARTWORK PROCESSING PIPELINE:
 * 1. Extract base64 artworkData from JSON payload
 * 2. Decode base64 string to NSData (handles 50KB-300KB artwork)
 * 3. Generate MD5 checksum for duplicate detection and performance optimization
 * 4. Create NSImage from decoded data with size validation
 * 5. Update properties and notify UI via NSNotificationCenter
 * 
 * PERFORMANCE OPTIMIZATIONS:
 * - MD5 checksums prevent redundant processing of identical artwork
 * - Early return for empty payloads to avoid unnecessary processing
 * - Checksum comparison before expensive NSImage creation
 * 
 * ERROR HANDLING:
 * - Validates base64 data integrity before processing
 * - Handles NSImage creation failures gracefully
 * - Logs critical errors for debugging artwork delivery issues
 * 
 * @param payload Dictionary containing media metadata and optional base64 artwork data
 *                Keys include: title, artist, album, artworkData, playing, elapsedTime, etc.
 */
/**
 * ARTWORK PROCESSING PIPELINE: Phase 2 - Data Processing
 * ====================================================
 * 
 * Handles JSON payload from media-control stream containing track metadata and base64 artwork.
 * Implements intelligent change detection to prevent UI flashing during song transitions.
 * 
 * KEY FEATURES:
 * - MD5 checksum validation prevents redundant artwork updates for same album
 * - Two-phase detection: metadata arrives first, artwork typically follows in next message
 * - Comprehensive logging for real-time troubleshooting at /tmp/mediabar-debug.log
 * - Memory-efficient base64 decoding with proper NSImage lifecycle management
 * 
 * PAYLOAD STRUCTURE (from media-control):
 * {
 *   "title": "Song Title",
 *   "artist": "Artist Name", 
 *   "album": "Album Name",
 *   "playing": true/false,
 *   "artworkData": "base64-encoded-image-data-50KB-300KB",
 *   "artworkMimeType": "image/png" or "image/jpeg"
 * }
 */
- (void)updateFromMediaControlData:(NSDictionary *)payload {
    if (!payload || [payload count] == 0) return;
    
    // Comprehensive debug logging for artwork troubleshooting
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
