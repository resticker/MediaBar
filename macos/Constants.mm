#include "Constants.h"

NSImage *spotifyRequestPermissionsAlbumArtwork = [NSImage imageNamed:@"Spotify Request Permissions Album Artwork"];
NSString *spotifyBundleIdentifier = @"com.spotify.client";

//NSString *const kPreferenceGlobalShortcutPlayPause = @"GlobalShortcut";
NSString *const kPreferenceGlobalShortcutPlayPause = @"PlayPauseShortcut";
NSString *const kPreferenceGlobalShortcutPreviousTrack = @"PreviousTrackShortcut";
NSString *const kPreferenceGlobalShortcutNextTrack = @"NextTrackShortcut";
NSString *const kPreferenceGlobalShortcutSkipBackward = @"SkipBackwardShortcut";
NSString *const kPreferenceGlobalShortcutSkipForward = @"SkipForwardShortcut";

NSString *ShowArtistUserDefaultsKey = @"MBShowArtist";
NSString *ShowTitleUserDefaultsKey = @"MBShowTitle";
NSString *ShowAlbumUserDefaultsKey = @"MBShowAlbum";
NSString *ShowRemainingTimeUserDefaultsKey = @"MBShowRemainingTime";
NSString *HideTextWhenPausedUserDefaultsKey = @"MBHideTextWhenPaused";
NSString *IconUserDefaultsKey = @"MBIcon";
NSString *IconWhilePlayingUserDefaultsKey = @"MBIconWhilePlaying";
NSString *MaximumWidthUserDefaultsKey = @"MBMaximumWidth";
NSString *EnableErrorReportingUserDefaultsKey = @"MBEnableErrorReporting";
NSString *EnableAutomaticUpdatesUserDefaultsKey = @"MBEnableAutomaticUpdates";
NSString *ProductHuntNotificationDisplayedUserDefaultsKey = @"MBProductHuntNotificationDisplayedUserDefaultsKey";
NSString *SetupCompletedUserDefaultsKey = @"MBSetupCompletedUserDefaultsKey";
NSString *SkipBackwardDurationUserDefaultsKey = @"MBSkipBackwardDuration";
NSString *SkipForwardDurationUserDefaultsKey = @"MBSkipForwardDuration";

NSString *SetupCompletedNotificationName = @"MBSetupCompleted";

NSFont *StatusItemIconFont = [NSFont fontWithName:@"musicbar" size:14.0f];
NSFont *StatusItemTextFont = [NSFont systemFontOfSize:14.0f];
