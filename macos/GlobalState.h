#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const struct GlobalStateNotificationStruct {
    NSString * _Nonnull infoDidChange;
    NSString * _Nonnull isPlayingDidChange;
} GlobalStateNotification;

/**
 * MediaBar's central state management class handling real-time media information and artwork display.
 * 
 * ARTWORK SYSTEM ARCHITECTURE:
 * ============================
 * 
 * 1. MEDIA-CONTROL INTEGRATION:
 *    - Spawns `media-control stream --no-diff` process for real-time media updates
 *    - Receives JSON objects containing metadata (title, artist) and base64 artwork data
 *    - Uses NSTask with proper environment variables (PATH, DYLD_FRAMEWORK_PATH) for framework loading
 * 
 * 2. TWO-PHASE DELIVERY PATTERN:
 *    - Media systems often deliver metadata first, then artwork in subsequent messages
 *    - Track changes are detected immediately, artwork may arrive milliseconds later
 *    - This prevents stale artwork being displayed for new tracks during transitions
 * 
 * 3. JSON BUFFERING SOLUTION:
 *    - Large artwork data (50KB-300KB) gets fragmented across multiple NSFileHandle reads
 *    - mediaControlBuffer accumulates partial data until complete JSON objects are available
 *    - Critical for preventing JSON parse failures that cause missing artwork
 * 
 * 4. ARTWORK PROCESSING PIPELINE:
 *    media-control stream → JSON buffering → artwork extraction → base64 decode → 
 *    NSImage creation → checksum validation → UI notification → AppDelegate display
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - MD5 checksums prevent redundant artwork updates for same album
 *    - Images resized to 18x18 points for status bar display efficiency
 *    - Memory cleanup via buffer trimming and proper NSImage lifecycle management
 * 
 * KEY METHODS:
 * - startMediaControlStream: Initializes media-control integration with proper environment
 * - processMediaControlOutput: Handles JSON buffering and parsing from fragmented stream data
 * - updateFromMediaControlData: Processes artwork data, validates changes, updates properties
 * 
 * DEBUGGING:
 * - Extensive logging to /tmp/mediabar-debug.log for real-time troubleshooting
 * - Debug logs include buffer state, JSON sizes, artwork processing results
 */
@interface GlobalState : NSObject

@property (atomic) BOOL isPlaying;
@property (atomic, nullable) NSString *title;
@property (atomic, nullable) NSString *artist;
@property (atomic, nullable) NSString *album;
@property (atomic, nullable) NSImage *albumArtwork;
@property (atomic, nullable) NSString *albumArtworkChecksum;
@property (atomic, nullable) NSDate *timestamp;
@property (atomic) double duration;
@property (nonatomic) double elapsedTime;
@property (atomic) NSInteger skipBackwardDuration;
@property (atomic) NSInteger skipForwardDuration;

#pragma mark - Actions

- (double)getElapsedTime;
- (void)togglePlayPause;
- (void)previous;
- (void)skipBackward;
- (void)skipForward;
- (void)next;

#pragma mark - Media Control Integration

/**
 * Buffer for accumulating JSON data from media-control stream across multiple read operations.
 * 
 * CRITICAL: Large artwork data (50KB-300KB base64) gets fragmented across multiple NSFileHandle
 * reads. This buffer accumulates partial JSON until complete objects are available for parsing.
 * Without buffering, JSON parsing fails on incomplete fragments, causing missing artwork.
 * 
 * The buffer is managed by processMediaControlOutput: which:
 * 1. Appends new data from each read operation
 * 2. Processes complete JSON objects (terminated by \n)
 * 3. Removes processed data to prevent memory accumulation
 */
@property (atomic, strong) NSMutableString *mediaControlBuffer;

#pragma mark - Error Handling & Recovery

/**
 * Properties for robust error handling and stream restart management.
 * 
 * currentBackoffDelay: Exponential backoff delay for stream restarts (starts at 1.0s, max 30.0s)
 * restartAttempts: Counter for consecutive restart attempts (resets after successful operation)
 */
@property (atomic) NSTimeInterval currentBackoffDelay;
@property (atomic) NSInteger restartAttempts;
@property (atomic, nullable) NSDate *lastStreamDataTime;

#pragma mark - Performance Optimization

/**
 * Cache for MD5 checksums to avoid recalculating for identical artwork data.
 * 
 * Key: Base64 artwork string (first 64 chars for memory efficiency)
 * Value: MD5 checksum string
 * 
 * This prevents redundant MD5 calculations when the same artwork appears
 * across multiple metadata updates (common with streaming services).
 */
@property (atomic, strong) NSMutableDictionary<NSString *, NSString *> *artworkChecksumCache;

#pragma mark - Debug
- (void)debugLog:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
