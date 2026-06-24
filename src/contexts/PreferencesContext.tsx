import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { persistence, setPersistenceSyncPreferences } from '../services/persistence';
import type { SyncPreferences } from '../services/persistence';

export type AnnouncementLevel = 'simple' | 'normal' | 'all';
export type DefaultForumFilter = 'All' | 'New';
export type CardDensity = 'comfortable' | 'compact';
export type PlaybackSpeed = 0.5 | 0.75 | 1.0 | 1.25 | 1.5 | 1.75 | 2.0 | 2.5 | 3.0;
export type PodcastEQPreset = 'flat' | 'speech' | 'bassBoost' | 'trebleBoost';
export type PodcastAutoDownload = 'off' | 'wifiOnly' | 'always';
export type PodcastAutoDelete = 'off' | 'immediate' | '1day' | '3days' | '7days';
export type PodcastResumeRewind = 0 | 10 | 15 | 30;

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

export type NotificationSound = 'mouseSqueak' | 'appleCrunch' | 'goldenRetrieverBark' | 'none';

const DEFAULT_NOTIFICATION_PREFS: NotificationPrefs = {
  forumReplies:   false,
  mentions:       false,
  newTopics:      false,
  followedTopics: false,
  newEpisodes:    false,
  appUpdates:     false,
  newResources:   false,
  announcements:  false,
};

const KEYS = {
  announcementLevel:          '@applevis_announcement_level',
  defaultForumFilter:         '@applevis_default_forum_filter',
  cardDensity:                '@applevis_card_density',
  helpfulTipsEnabled:         '@applevis_helpful_tips_enabled',
  welcomeSummaryEnabled:      '@applevis_welcome_summary_enabled',
  notificationPrefs:          '@applevis_notification_prefs',
  notificationSound:          '@applevis_notification_sound',
  nonEnglishDetectionEnabled: '@applevis_non_english_detection',
  composeRewriteEnabled:      '@applevis_compose_rewrite_enabled',
  composeTranslationEnabled:  '@applevis_compose_translation_enabled',
  searchTranslationEnabled:   '@applevis_search_translation_enabled',
  aiSummariesEnabled:         '@applevis_ai_summaries_enabled',
  podcastSpeed:               '@applevis_podcast_speed',
  podcastSkipBack:            '@applevis_podcast_skip_back',
  podcastSkipForward:         '@applevis_podcast_skip_forward',
  podcastAutoPlay:            '@applevis_podcast_auto_play',
  podcastSleepTimer:          '@applevis_podcast_sleep_timer',
  podcastVoiceBoost:          '@applevis_podcast_voice_boost',
  podcastEQ:                  '@applevis_podcast_eq',
  podcastAutoDownload:        '@applevis_podcast_auto_download',
  podcastAutoDelete:          '@applevis_podcast_auto_delete',
  podcastTrimSilence:         '@applevis_podcast_trim_silence',
  podcastResumeRewind:        '@applevis_podcast_resume_rewind',
  iCloudSync:                 '@applevis_sync_icloud',
  savedItemsSync:             '@applevis_sync_saved_items',
  readingPositionSync:        '@applevis_sync_reading_position',
  podcastPositionSync:        '@applevis_sync_podcast_position',
  queueSync:                  '@applevis_sync_queue',
  settingsSync:               '@applevis_sync_settings',
};

type PreferencesContextValue = {
  announcementLevel:    AnnouncementLevel;
  setAnnouncementLevel: (v: AnnouncementLevel) => void;

  defaultForumFilter:    DefaultForumFilter;
  setDefaultForumFilter: (v: DefaultForumFilter) => void;

  cardDensity:    CardDensity;
  setCardDensity: (v: CardDensity) => void;

  helpfulTipsEnabled:    boolean;
  setHelpfulTipsEnabled: (v: boolean) => void;

  welcomeSummaryEnabled:    boolean;
  setWelcomeSummaryEnabled: (v: boolean) => void;

  notificationPrefs:    NotificationPrefs;
  setNotificationPrefs: (v: NotificationPrefs) => void;

  notificationSound:    NotificationSound;
  setNotificationSound: (v: NotificationSound) => void;

  nonEnglishDetectionEnabled:    boolean;
  setNonEnglishDetectionEnabled: (v: boolean) => void;

  // ── Podcast player defaults ────────────────────────────────────────────────
  composeRewriteEnabled:    boolean;
  setComposeRewriteEnabled: (v: boolean) => void;

  composeTranslationEnabled:    boolean;
  setComposeTranslationEnabled: (v: boolean) => void;

  searchTranslationEnabled:    boolean;
  setSearchTranslationEnabled: (v: boolean) => void;

  aiSummariesEnabled:    boolean;
  setAiSummariesEnabled: (v: boolean) => void;

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

  podcastTrimSilence:    boolean;
  setPodcastTrimSilence: (v: boolean) => void;

  podcastResumeRewind:    PodcastResumeRewind;
  setPodcastResumeRewind: (v: PodcastResumeRewind) => void;

  syncPreferences:    SyncPreferences;
  setSyncPreference:  (key: keyof SyncPreferences, value: boolean) => void;

  /** True while preferences are being loaded from storage. */
  isLoading: boolean;
};

const PreferencesContext = createContext<PreferencesContextValue | null>(null);

export function PreferencesProvider({ children }: { children: React.ReactNode }) {
  const [isLoading,           setIsLoading]               = useState(true);
  const [announcementLevel,   setAnnouncementLevelState]   = useState<AnnouncementLevel>('all');
  const [defaultForumFilter,  setDefaultForumFilterState]  = useState<DefaultForumFilter>('All');
  const [cardDensity,         setCardDensityState]         = useState<CardDensity>('comfortable');
  const [helpfulTipsEnabled,  setHelpfulTipsEnabledState]  = useState<boolean>(true);
  const [welcomeSummaryEnabled, setWelcomeSummaryEnabledState] = useState<boolean>(true);
  const [notificationPrefs,           setNotificationPrefsState]           = useState<NotificationPrefs>(DEFAULT_NOTIFICATION_PREFS);
  const [notificationSound,           setNotificationSoundState]           = useState<NotificationSound>('mouseSqueak');
  const [nonEnglishDetectionEnabled,  setNonEnglishDetectionEnabledState]  = useState<boolean>(true);
  const [composeRewriteEnabled,       setComposeRewriteEnabledState]       = useState<boolean>(true);
  const [composeTranslationEnabled,   setComposeTranslationEnabledState]   = useState<boolean>(true);
  const [searchTranslationEnabled,    setSearchTranslationEnabledState]    = useState<boolean>(true);
  const [aiSummariesEnabled,          setAiSummariesEnabledState]          = useState<boolean>(true);
  const [podcastSpeed,        setPodcastSpeedState]        = useState<PlaybackSpeed>(1.0);
  const [podcastSkipBack,     setPodcastSkipBackState]     = useState<number>(15);
  const [podcastSkipForward,  setPodcastSkipForwardState]  = useState<number>(30);
  const [podcastAutoPlay,     setPodcastAutoPlayState]     = useState<boolean>(true);
  const [podcastSleepTimer,   setPodcastSleepTimerState]   = useState<number | null>(null);
  const [podcastVoiceBoost,   setPodcastVoiceBoostState]   = useState<boolean>(false);
  const [podcastEQ,           setPodcastEQState]           = useState<PodcastEQPreset>('flat');
  const [podcastAutoDownload, setPodcastAutoDownloadState] = useState<PodcastAutoDownload>('off');
  const [podcastAutoDelete,   setPodcastAutoDeleteState]   = useState<PodcastAutoDelete>('off');
  const [podcastTrimSilence,    setPodcastTrimSilenceState]    = useState<boolean>(false);
  const [podcastResumeRewind,   setPodcastResumeRewindState]   = useState<PodcastResumeRewind>(15);
  const [syncPreferences,       setSyncPreferencesState]        = useState<SyncPreferences>({
    iCloudSync: true,
    savedItemsSync: true,
    readingPositionSync: true,
    podcastPositionSync: true,
    queueSync: true,
    settingsSync: true,
  });

  useEffect(() => {
    const uiLoads = Promise.all([
      AsyncStorage.getItem(KEYS.announcementLevel),
      AsyncStorage.getItem(KEYS.defaultForumFilter),
      AsyncStorage.getItem(KEYS.cardDensity),
      AsyncStorage.getItem(KEYS.notificationPrefs),
      AsyncStorage.getItem(KEYS.notificationSound),
      AsyncStorage.getItem(KEYS.nonEnglishDetectionEnabled),
      AsyncStorage.getItem(KEYS.composeRewriteEnabled),
      AsyncStorage.getItem(KEYS.composeTranslationEnabled),
      AsyncStorage.getItem(KEYS.searchTranslationEnabled),
      AsyncStorage.getItem(KEYS.aiSummariesEnabled),
    ]);

    const podcastLoads = Promise.all([
      persistence.getSetting<PlaybackSpeed>(KEYS.podcastSpeed, 1.0),
      persistence.getSetting<number>(KEYS.podcastSkipBack, 15),
      persistence.getSetting<number>(KEYS.podcastSkipForward, 30),
      persistence.getSetting<boolean>(KEYS.podcastAutoPlay, true),
      persistence.getSetting<number | null>(KEYS.podcastSleepTimer, null),
      persistence.getSetting<boolean>(KEYS.podcastVoiceBoost, false),
      persistence.getSetting<PodcastEQPreset>(KEYS.podcastEQ, 'flat'),
      persistence.getSetting<PodcastAutoDownload>(KEYS.podcastAutoDownload, 'off'),
      persistence.getSetting<PodcastAutoDelete>(KEYS.podcastAutoDelete, 'off'),
      persistence.getSetting<boolean>(KEYS.podcastTrimSilence, false),
      persistence.getSetting<PodcastResumeRewind>(KEYS.podcastResumeRewind, 15),
      persistence.getSetting<boolean>(KEYS.helpfulTipsEnabled, true),
      persistence.getSetting<boolean>(KEYS.welcomeSummaryEnabled, true),
    ]);

    const syncLoads = Promise.all([
      AsyncStorage.getItem(KEYS.iCloudSync),
      AsyncStorage.getItem(KEYS.savedItemsSync),
      AsyncStorage.getItem(KEYS.readingPositionSync),
      AsyncStorage.getItem(KEYS.podcastPositionSync),
      AsyncStorage.getItem(KEYS.queueSync),
      AsyncStorage.getItem(KEYS.settingsSync),
    ]);

    Promise.all([uiLoads, podcastLoads, syncLoads])
      .then(([[level, filter, density, prefs, sound, nonEnglish, composeRewrite, composeTranslation, searchTranslation, aiSummaries],
              [speed, skipB, skipF, autoPlay, sleep, vBoost, eq, autoDl, autoDel, trimSilence, resumeRewind, helpfulTips, welcomeSummary],
              [iCloudSync, savedItemsSync, readingPositionSync, podcastPositionSync, queueSync, settingsSync]]) => {
        if (level)      setAnnouncementLevelState(level as AnnouncementLevel);
        if (filter === 'All' || filter === 'New') setDefaultForumFilterState(filter);
        if (density)    setCardDensityState(density as CardDensity);
        if (prefs)      setNotificationPrefsState(JSON.parse(prefs) as NotificationPrefs);
        if (sound)      setNotificationSoundState(sound as NotificationSound);
        if (nonEnglish) setNonEnglishDetectionEnabledState(nonEnglish === 'true');
        if (composeRewrite)     setComposeRewriteEnabledState(composeRewrite === 'true');
        if (composeTranslation) setComposeTranslationEnabledState(composeTranslation === 'true');
        if (searchTranslation)  setSearchTranslationEnabledState(searchTranslation === 'true');
        if (aiSummaries)        setAiSummariesEnabledState(aiSummaries === 'true');

        setPodcastSpeedState(speed);
        setPodcastSkipBackState(skipB);
        setPodcastSkipForwardState(skipF);
        setPodcastAutoPlayState(autoPlay);
        setPodcastSleepTimerState(sleep);
        setPodcastVoiceBoostState(vBoost);
        setPodcastEQState(eq);
        setPodcastAutoDownloadState(autoDl);
        setPodcastAutoDeleteState((autoDel as PodcastAutoDelete | '1week') === '1week' ? '7days' : autoDel);
        setPodcastTrimSilenceState(trimSilence);
        setPodcastResumeRewindState(resumeRewind);
        setHelpfulTipsEnabledState(helpfulTips);
        setWelcomeSummaryEnabledState(welcomeSummary);
        const nextSyncPreferences: SyncPreferences = {
          iCloudSync: iCloudSync !== 'false',
          savedItemsSync: savedItemsSync !== 'false',
          readingPositionSync: readingPositionSync !== 'false',
          podcastPositionSync: podcastPositionSync !== 'false',
          queueSync: queueSync !== 'false',
          settingsSync: settingsSync !== 'false',
        };
        setSyncPreferencesState(nextSyncPreferences);
        setPersistenceSyncPreferences(nextSyncPreferences);
      })
      .finally(() => setIsLoading(false));
  }, []);

  useEffect(() => {
    setPersistenceSyncPreferences(syncPreferences);
  }, [syncPreferences]);

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

  const setHelpfulTipsEnabled = useCallback((v: boolean) => {
    setHelpfulTipsEnabledState(v);
    persistence.setSetting(KEYS.helpfulTipsEnabled, v).catch(() => {});
  }, []);

  const setWelcomeSummaryEnabled = useCallback((v: boolean) => {
    setWelcomeSummaryEnabledState(v);
    persistence.setSetting(KEYS.welcomeSummaryEnabled, v).catch(() => {});
  }, []);

  const setNotificationPrefs = useCallback((v: NotificationPrefs) => {
    setNotificationPrefsState(v);
    AsyncStorage.setItem(KEYS.notificationPrefs, JSON.stringify(v)).catch(() => {});
  }, []);

  const setNotificationSound = useCallback((v: NotificationSound) => {
    setNotificationSoundState(v);
    AsyncStorage.setItem(KEYS.notificationSound, v).catch(() => {});
  }, []);

  const setNonEnglishDetectionEnabled = useCallback((v: boolean) => {
    setNonEnglishDetectionEnabledState(v);
    AsyncStorage.setItem(KEYS.nonEnglishDetectionEnabled, String(v)).catch(() => {});
  }, []);

  const setComposeRewriteEnabled = useCallback((v: boolean) => {
    setComposeRewriteEnabledState(v);
    AsyncStorage.setItem(KEYS.composeRewriteEnabled, String(v)).catch(() => {});
  }, []);

  const setComposeTranslationEnabled = useCallback((v: boolean) => {
    setComposeTranslationEnabledState(v);
    AsyncStorage.setItem(KEYS.composeTranslationEnabled, String(v)).catch(() => {});
  }, []);

  const setSearchTranslationEnabled = useCallback((v: boolean) => {
    setSearchTranslationEnabledState(v);
    AsyncStorage.setItem(KEYS.searchTranslationEnabled, String(v)).catch(() => {});
  }, []);

  const setAiSummariesEnabled = useCallback((v: boolean) => {
    setAiSummariesEnabledState(v);
    AsyncStorage.setItem(KEYS.aiSummariesEnabled, String(v)).catch(() => {});
  }, []);

  const setPodcastSpeed = useCallback((v: PlaybackSpeed) => {
    setPodcastSpeedState(v);
    persistence.setSetting(KEYS.podcastSpeed, v).catch(() => {});
  }, []);
  const setPodcastSkipBack = useCallback((v: number) => {
    setPodcastSkipBackState(v);
    persistence.setSetting(KEYS.podcastSkipBack, v).catch(() => {});
  }, []);
  const setPodcastSkipForward = useCallback((v: number) => {
    setPodcastSkipForwardState(v);
    persistence.setSetting(KEYS.podcastSkipForward, v).catch(() => {});
  }, []);
  const setPodcastAutoPlay = useCallback((v: boolean) => {
    setPodcastAutoPlayState(v);
    persistence.setSetting(KEYS.podcastAutoPlay, v).catch(() => {});
  }, []);
  const setPodcastSleepTimer = useCallback((v: number | null) => {
    setPodcastSleepTimerState(v);
    persistence.setSetting(KEYS.podcastSleepTimer, v).catch(() => {});
  }, []);
  const setPodcastVoiceBoost = useCallback((v: boolean) => {
    setPodcastVoiceBoostState(v);
    persistence.setSetting(KEYS.podcastVoiceBoost, v).catch(() => {});
  }, []);
  const setPodcastEQ = useCallback((v: PodcastEQPreset) => {
    setPodcastEQState(v);
    persistence.setSetting(KEYS.podcastEQ, v).catch(() => {});
  }, []);
  const setPodcastAutoDownload = useCallback((v: PodcastAutoDownload) => {
    setPodcastAutoDownloadState(v);
    persistence.setSetting(KEYS.podcastAutoDownload, v).catch(() => {});
  }, []);
  const setPodcastAutoDelete = useCallback((v: PodcastAutoDelete) => {
    setPodcastAutoDeleteState(v);
    persistence.setSetting(KEYS.podcastAutoDelete, v).catch(() => {});
  }, []);
  const setPodcastTrimSilence = useCallback((v: boolean) => {
    setPodcastTrimSilenceState(v);
    persistence.setSetting(KEYS.podcastTrimSilence, v).catch(() => {});
  }, []);
  const setPodcastResumeRewind = useCallback((v: PodcastResumeRewind) => {
    setPodcastResumeRewindState(v);
    persistence.setSetting(KEYS.podcastResumeRewind, v).catch(() => {});
  }, []);

  const setSyncPreference = useCallback((key: keyof SyncPreferences, value: boolean) => {
    setSyncPreferencesState((prev) => {
      const next = { ...prev, [key]: value };
      if (key === 'iCloudSync' && !value) {
        next.savedItemsSync = false;
        next.readingPositionSync = false;
        next.podcastPositionSync = false;
        next.queueSync = false;
        next.settingsSync = false;
      }
      if (key !== 'iCloudSync' && value) next.iCloudSync = true;

      AsyncStorage.setItem(KEYS.iCloudSync, String(next.iCloudSync)).catch(() => {});
      AsyncStorage.setItem(KEYS.savedItemsSync, String(next.savedItemsSync)).catch(() => {});
      AsyncStorage.setItem(KEYS.readingPositionSync, String(next.readingPositionSync)).catch(() => {});
      AsyncStorage.setItem(KEYS.podcastPositionSync, String(next.podcastPositionSync)).catch(() => {});
      AsyncStorage.setItem(KEYS.queueSync, String(next.queueSync)).catch(() => {});
      AsyncStorage.setItem(KEYS.settingsSync, String(next.settingsSync)).catch(() => {});
      setPersistenceSyncPreferences(next);
      return next;
    });
  }, []);

  const value = useMemo<PreferencesContextValue>(() => ({
    announcementLevel,  setAnnouncementLevel,
    defaultForumFilter, setDefaultForumFilter,
    cardDensity,        setCardDensity,
    helpfulTipsEnabled, setHelpfulTipsEnabled,
    welcomeSummaryEnabled, setWelcomeSummaryEnabled,
    notificationPrefs,  setNotificationPrefs,
    notificationSound,  setNotificationSound,
    nonEnglishDetectionEnabled, setNonEnglishDetectionEnabled,
    composeRewriteEnabled, setComposeRewriteEnabled,
    composeTranslationEnabled, setComposeTranslationEnabled,
    searchTranslationEnabled, setSearchTranslationEnabled,
    aiSummariesEnabled, setAiSummariesEnabled,
    podcastSpeed,        setPodcastSpeed,
    podcastSkipBack,     setPodcastSkipBack,
    podcastSkipForward,  setPodcastSkipForward,
    podcastAutoPlay,     setPodcastAutoPlay,
    podcastSleepTimer,   setPodcastSleepTimer,
    podcastVoiceBoost,   setPodcastVoiceBoost,
    podcastEQ,           setPodcastEQ,
    podcastAutoDownload, setPodcastAutoDownload,
    podcastAutoDelete,    setPodcastAutoDelete,
    podcastTrimSilence,   setPodcastTrimSilence,
    podcastResumeRewind,  setPodcastResumeRewind,
    syncPreferences,      setSyncPreference,
    isLoading,
  }), [
    announcementLevel, defaultForumFilter, cardDensity,
    helpfulTipsEnabled, welcomeSummaryEnabled, notificationPrefs, notificationSound, nonEnglishDetectionEnabled,
    composeRewriteEnabled, composeTranslationEnabled, searchTranslationEnabled, aiSummariesEnabled,
    podcastSpeed, podcastSkipBack, podcastSkipForward, podcastAutoPlay,
    podcastSleepTimer, podcastVoiceBoost, podcastEQ, podcastAutoDownload, podcastAutoDelete, podcastTrimSilence,
    syncPreferences,
    isLoading,
    setAnnouncementLevel, setDefaultForumFilter, setCardDensity, setHelpfulTipsEnabled, setWelcomeSummaryEnabled,
    setNotificationPrefs, setNotificationSound, setNonEnglishDetectionEnabled,
    setComposeRewriteEnabled, setComposeTranslationEnabled, setSearchTranslationEnabled, setAiSummariesEnabled,
    setPodcastSpeed, setPodcastSkipBack, setPodcastSkipForward, setPodcastAutoPlay,
    setPodcastSleepTimer, setPodcastVoiceBoost, setPodcastEQ, setPodcastAutoDownload, setPodcastAutoDelete,
    setPodcastTrimSilence, podcastResumeRewind, setPodcastResumeRewind, setSyncPreference,
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
