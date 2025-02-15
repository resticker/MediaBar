#import <AppKit/AppKit.h>

#ifndef Constants_h
#define Constants_h

extern NSImage *spotifyRequestPermissionsAlbumArtwork;
extern NSString *spotifyBundleIdentifier;

extern NSString *const kPreferenceGlobalShortcutPlayPause;
extern NSString *const kPreferenceGlobalShortcutPreviousTrack;
extern NSString *const kPreferenceGlobalShortcutNextTrack;
extern NSString *const kPreferenceGlobalShortcutSkipBackward;
extern NSString *const kPreferenceGlobalShortcutSkipForward;

extern NSString *ShowArtistUserDefaultsKey;
extern NSString *ShowTitleUserDefaultsKey;
extern NSString *ShowAlbumUserDefaultsKey;
extern NSString *ShowRemainingTimeUserDefaultsKey;
extern NSString *HideTextWhenPausedUserDefaultsKey;
extern NSString *IconUserDefaultsKey;
extern NSString *IconWhilePlayingUserDefaultsKey;
extern NSString *MaximumWidthUserDefaultsKey;
extern NSString *EnableErrorReportingUserDefaultsKey;
extern NSString *EnableAutomaticUpdatesUserDefaultsKey;
extern NSString *ProductHuntNotificationDisplayedUserDefaultsKey;
extern NSString *SetupCompletedUserDefaultsKey;
extern NSString *SkipBackwardDurationUserDefaultsKey;
extern NSString *SkipForwardDurationUserDefaultsKey;

extern NSString *SetupCompletedNotificationName;

extern NSFont *StatusItemIconFont;
extern NSFont *StatusItemTextFont;

#endif /* Constants_h */
