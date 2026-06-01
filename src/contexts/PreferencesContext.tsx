import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

export type AnnouncementLevel = 'simple' | 'normal' | 'all';
export type DefaultForumFilter = 'Recent' | 'Since Last Visit' | 'Unread';
export type CardDensity = 'comfortable' | 'compact';
export type PlaybackSpeed = 0.5 | 0.75 | 1.0 | 1.25 | 1.5 | 1.75 | 2.0 | 2.5 | 3.0;
export type PodcastEQPreset = 'flat' | 'speech' | 'bassBoost' | 'trebleBoost';
export type PodcastAutoDownload = 'off' | 'wifiOnly' | 'always';
export type PodcastAutoDelete = 'off' | '1day' | '1week';

export type NotificationPrefs = {
  forumReplies:   boolean;
  mentions:       boolean;
  newTopics:      boolean;
  followedTopics: boolean;
  newEpisodes:    boolean;
  appUpdates:     boolean;
  newResources:   boolean;
  announcements:  boolean;
};

export type NotificationSound = 'mouseSqueak' | 'appleCrunch' | 'none';

const DEFAULT_NOTIFICATION_PREFS: NotificationPrefs = {
  forumReplies:   true,
  mentions:       true,
  newTopics:      true,
  followedTopics: true,
  newEpisodes:    true,
  appUpdates:     true,
  newResources:   true,
  announcements:  true,
};

const KEYS = {
  announcementLevel:    '@applevis_announcement_level',
  defaultForumFilter:   '@applevis_default_forum_filter',
  cardDensity:          '@applevis_card_density',
  notificationPrefs:    '@applevis_notification_prefs',
  notificationSound:    '@applevis_notification_sound',
  podcastSpeed:         '@applevis_podcast_speed',
  podcastSkipBack:      '@applevis_podcast_skip_back',
  podcastSkipForward:   '@applevis_podcast_skip_forward',
  podcastAutoPlay:      '@applevis_podcast_auto_play',
  podcastSleepTimer:    '@applevis_podcast_sleep_timer',
  podcastVoiceBoost:    '@applevis_podcast_voice_boost',
  podcastEQ:            '@applevis_podcast_eq',
  podcastAutoDownload:  '@applevis_podcast_auto_download',
  podcastAutoDelete:    '@applevis_podcast_auto_delete',
};

type PreferencesContextValue = {
  announcementLevel:    AnnouncementLevel;
  setAnnouncementLevel: (v: AnnouncementLevel) => void;

  defaultForumFilter:    DefaultForumFilter;
  setDefaultForumFilter: (v: DefaultForumFilter) => void;

  cardDensity:    CardDensity;
  setCardDensity: (v: CardDensity) => void;

  notificationPrefs:    NotificationPrefs;
  setNotificationPrefs: (v: NotificationPrefs) => void;

  notificationSound:    NotificationSound;
  setNotificationSound: (v: NotificationSound) => void;

  // ── Podcast player defaults ────────────────────────────────────────────────
  podcastSpeed:         PlaybackSpeed;
  setPodcastSpeed:      (v: PlaybackSpeed) => void;

  podcastSkipBack:      number;
  setPodcastSkipBack:   (v: number) => void;

  podcastSkipForward:   number;
  setPodcastSkipForward:(v: number) => void;

  podcastAutoPlay:      boolean;
  setPodcastAutoPlay:   (v: boolean) => void;

  podcastSleepTimer:    number | null;
  setPodcastSleepTimer: (v: number | null) => void;

  podcastVoiceBoost:    boolean;
  setPodcastVoiceBoost: (v: boolean) => void;

  podcastEQ:            PodcastEQPreset;
  setPodcastEQ:         (v: PodcastEQPreset) => void;

  podcastAutoDownload:  PodcastAutoDownload;
  setPodcastAutoDownload:(v: PodcastAutoDownload) => void;

  podcastAutoDelete:    PodcastAutoDelete;
  setPodcastAutoDelete: (v: PodcastAutoDelete) => void;

  /** True while preferences are being loaded from storage. */
  isLoading: boolean;
};

const PreferencesContext = createContext<PreferencesContextValue | null>(null);

export function PreferencesProvider({ children }: { children: React.ReactNode }) {
  const [isLoading,           setIsLoading]               = useState(true);
  const [announcementLevel,   setAnnouncementLevelState]   = useState<AnnouncementLevel>('all');
  const [defaultForumFilter,  setDefaultForumFilterState]  = useState<DefaultForumFilter>('Recent');
  const [cardDensity,         setCardDensityState]         = useState<CardDensity>('comfortable');
  const [notificationPrefs,   setNotificationPrefsState]   = useState<NotificationPrefs>(DEFAULT_NOTIFICATION_PREFS);
  const [notificationSound,   setNotificationSoundState]   = useState<NotificationSound>('mouseSqueak');
  const [podcastSpeed,        setPodcastSpeedState]        = useState<PlaybackSpeed>(1.0);
  const [podcastSkipBack,     setPodcastSkipBackState]     = useState<number>(10);
  const [podcastSkipForward,  setPodcastSkipForwardState]  = useState<number>(30);
  const [podcastAutoPlay,     setPodcastAutoPlayState]     = useState<boolean>(true);
  const [podcastSleepTimer,   setPodcastSleepTimerState]   = useState<number | null>(null);
  const [podcastVoiceBoost,   setPodcastVoiceBoostState]   = useState<boolean>(false);
  const [podcastEQ,           setPodcastEQState]           = useState<PodcastEQPreset>('flat');
  const [podcastAutoDownload, setPodcastAutoDownloadState] = useState<PodcastAutoDownload>('off');
  const [podcastAutoDelete,   setPodcastAutoDeleteState]   = useState<PodcastAutoDelete>('off');

  useEffect(() => {
    Promise.all([
      AsyncStorage.getItem(KEYS.announcementLevel),
      AsyncStorage.getItem(KEYS.defaultForumFilter),
      AsyncStorage.getItem(KEYS.cardDensity),
      AsyncStorage.getItem(KEYS.notificationPrefs),
      AsyncStorage.getItem(KEYS.notificationSound),
      AsyncStorage.getItem(KEYS.podcastSpeed),
      AsyncStorage.getItem(KEYS.podcastSkipBack),
      AsyncStorage.getItem(KEYS.podcastSkipForward),
      AsyncStorage.getItem(KEYS.podcastAutoPlay),
      AsyncStorage.getItem(KEYS.podcastSleepTimer),
      AsyncStorage.getItem(KEYS.podcastVoiceBoost),
      AsyncStorage.getItem(KEYS.podcastEQ),
      AsyncStorage.getItem(KEYS.podcastAutoDownload),
      AsyncStorage.getItem(KEYS.podcastAutoDelete),
    ]).then(([level, filter, density, prefs, sound, speed, skipB, skipF, autoPlay, sleep, vBoost, eq, autoDl, autoDel]) => {
      if (level)    setAnnouncementLevelState(level as AnnouncementLevel);
      if (filter)   setDefaultForumFilterState(filter as DefaultForumFilter);
      if (density)  setCardDensityState(density as CardDensity);
      if (prefs)    setNotificationPrefsState(JSON.parse(prefs) as NotificationPrefs);
      if (sound)    setNotificationSoundState(sound as NotificationSound);
      if (speed)    setPodcastSpeedState(parseFloat(speed) as PlaybackSpeed);
      if (skipB)    setPodcastSkipBackState(parseInt(skipB, 10));
      if (skipF)    setPodcastSkipForwardState(parseInt(skipF, 10));
      if (autoPlay) setPodcastAutoPlayState(autoPlay === 'true');
      if (sleep)    setPodcastSleepTimerState(sleep === 'null' ? null : parseInt(sleep, 10));
      if (vBoost)   setPodcastVoiceBoostState(vBoost === 'true');
      if (eq)       setPodcastEQState(eq as PodcastEQPreset);
      if (autoDl)   setPodcastAutoDownloadState(autoDl as PodcastAutoDownload);
      if (autoDel)  setPodcastAutoDeleteState(autoDel as PodcastAutoDelete);
    }).finally(() => setIsLoading(false));
  }, []);

  const setAnnouncementLevel = useCallback((v: AnnouncementLevel) => {
    setAnnouncementLevelState(v);
    AsyncStorage.setItem(KEYS.announcementLevel, v).catch(() => {});
  }, []);

  const setDefaultForumFilter = useCallback((v: DefaultForumFilter) => {
    setDefaultForumFilterState(v);
    AsyncStorage.setItem(KEYS.defaultForumFilter, v).catch(() => {});
  }, []);

  const setCardDensity = useCallback((v: CardDensity) => {
    setCardDensityState(v);
    AsyncStorage.setItem(KEYS.cardDensity, v).catch(() => {});
  }, []);

  const setNotificationPrefs = useCallback((v: NotificationPrefs) => {
    setNotificationPrefsState(v);
    AsyncStorage.setItem(KEYS.notificationPrefs, JSON.stringify(v)).catch(() => {});
  }, []);

  const setNotificationSound = useCallback((v: NotificationSound) => {
    setNotificationSoundState(v);
    AsyncStorage.setItem(KEYS.notificationSound, v).catch(() => {});
  }, []);

  const setPodcastSpeed = useCallback((v: PlaybackSpeed) => {
    setPodcastSpeedState(v);
    AsyncStorage.setItem(KEYS.podcastSpeed, String(v)).catch(() => {});
  }, []);
  const setPodcastSkipBack = useCallback((v: number) => {
    setPodcastSkipBackState(v);
    AsyncStorage.setItem(KEYS.podcastSkipBack, String(v)).catch(() => {});
  }, []);
  const setPodcastSkipForward = useCallback((v: number) => {
    setPodcastSkipForwardState(v);
    AsyncStorage.setItem(KEYS.podcastSkipForward, String(v)).catch(() => {});
  }, []);
  const setPodcastAutoPlay = useCallback((v: boolean) => {
    setPodcastAutoPlayState(v);
    AsyncStorage.setItem(KEYS.podcastAutoPlay, String(v)).catch(() => {});
  }, []);
  const setPodcastSleepTimer = useCallback((v: number | null) => {
    setPodcastSleepTimerState(v);
    AsyncStorage.setItem(KEYS.podcastSleepTimer, String(v)).catch(() => {});
  }, []);
  const setPodcastVoiceBoost = useCallback((v: boolean) => {
    setPodcastVoiceBoostState(v);
    AsyncStorage.setItem(KEYS.podcastVoiceBoost, String(v)).catch(() => {});
  }, []);
  const setPodcastEQ = useCallback((v: PodcastEQPreset) => {
    setPodcastEQState(v);
    AsyncStorage.setItem(KEYS.podcastEQ, v).catch(() => {});
  }, []);
  const setPodcastAutoDownload = useCallback((v: PodcastAutoDownload) => {
    setPodcastAutoDownloadState(v);
    AsyncStorage.setItem(KEYS.podcastAutoDownload, v).catch(() => {});
  }, []);
  const setPodcastAutoDelete = useCallback((v: PodcastAutoDelete) => {
    setPodcastAutoDeleteState(v);
    AsyncStorage.setItem(KEYS.podcastAutoDelete, v).catch(() => {});
  }, []);

  const value = useMemo<PreferencesContextValue>(() => ({
    announcementLevel,  setAnnouncementLevel,
    defaultForumFilter, setDefaultForumFilter,
    cardDensity,        setCardDensity,
    notificationPrefs,  setNotificationPrefs,
    notificationSound,  setNotificationSound,
    podcastSpeed,        setPodcastSpeed,
    podcastSkipBack,     setPodcastSkipBack,
    podcastSkipForward,  setPodcastSkipForward,
    podcastAutoPlay,     setPodcastAutoPlay,
    podcastSleepTimer,   setPodcastSleepTimer,
    podcastVoiceBoost,   setPodcastVoiceBoost,
    podcastEQ,           setPodcastEQ,
    podcastAutoDownload, setPodcastAutoDownload,
    podcastAutoDelete,   setPodcastAutoDelete,
    isLoading,
  }), [
    announcementLevel, defaultForumFilter, cardDensity,
    notificationPrefs, notificationSound,
    podcastSpeed, podcastSkipBack, podcastSkipForward, podcastAutoPlay,
    podcastSleepTimer, podcastVoiceBoost, podcastEQ, podcastAutoDownload, podcastAutoDelete,
    isLoading,
    setAnnouncementLevel, setDefaultForumFilter, setCardDensity,
    setNotificationPrefs, setNotificationSound,
    setPodcastSpeed, setPodcastSkipBack, setPodcastSkipForward, setPodcastAutoPlay,
    setPodcastSleepTimer, setPodcastVoiceBoost, setPodcastEQ, setPodcastAutoDownload, setPodcastAutoDelete,
  ]);

  return <PreferencesContext.Provider value={value}>{children}</PreferencesContext.Provider>;
}

export function usePreferences(): PreferencesContextValue {
  const ctx = useContext(PreferencesContext);
  if (!ctx) throw new Error('usePreferences must be inside PreferencesProvider');
  return ctx;
}

/** Builds the accessibilityLabel meta string for a content card based on announcement level. */
export function buildMeta(
  parts: (string | null | undefined)[],
  level: AnnouncementLevel,
): string {
  if (level === 'simple') return '';
  const clean = parts.filter((p): p is string => !!p);
  if (level === 'normal') return clean.slice(0, 2).join(' · ');
  return clean.join(' · ');
}
