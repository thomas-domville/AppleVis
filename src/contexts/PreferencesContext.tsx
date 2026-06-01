import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

export type AnnouncementLevel = 'simple' | 'normal' | 'all';
export type DefaultForumFilter = 'Recent' | 'Since Last Visit' | 'Unread';
export type CardDensity = 'comfortable' | 'compact';

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
  announcementLevel:  '@applevis_announcement_level',
  defaultForumFilter: '@applevis_default_forum_filter',
  cardDensity:        '@applevis_card_density',
  notificationPrefs:  '@applevis_notification_prefs',
  notificationSound:  '@applevis_notification_sound',
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

  /** True while preferences are being loaded from storage. */
  isLoading: boolean;
};

const PreferencesContext = createContext<PreferencesContextValue | null>(null);

export function PreferencesProvider({ children }: { children: React.ReactNode }) {
  const [isLoading,          setIsLoading]          = useState(true);
  const [announcementLevel,  setAnnouncementLevelState]  = useState<AnnouncementLevel>('all');
  const [defaultForumFilter, setDefaultForumFilterState] = useState<DefaultForumFilter>('Recent');
  const [cardDensity,        setCardDensityState]        = useState<CardDensity>('comfortable');
  const [notificationPrefs,  setNotificationPrefsState]  = useState<NotificationPrefs>(DEFAULT_NOTIFICATION_PREFS);
  const [notificationSound,  setNotificationSoundState]  = useState<NotificationSound>('mouseSqueak');

  useEffect(() => {
    Promise.all([
      AsyncStorage.getItem(KEYS.announcementLevel),
      AsyncStorage.getItem(KEYS.defaultForumFilter),
      AsyncStorage.getItem(KEYS.cardDensity),
      AsyncStorage.getItem(KEYS.notificationPrefs),
      AsyncStorage.getItem(KEYS.notificationSound),
    ]).then(([level, filter, density, prefs, sound]) => {
      if (level)   setAnnouncementLevelState(level as AnnouncementLevel);
      if (filter)  setDefaultForumFilterState(filter as DefaultForumFilter);
      if (density) setCardDensityState(density as CardDensity);
      if (prefs)   setNotificationPrefsState(JSON.parse(prefs) as NotificationPrefs);
      if (sound)   setNotificationSoundState(sound as NotificationSound);
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

  const value = useMemo<PreferencesContextValue>(() => ({
    announcementLevel,  setAnnouncementLevel,
    defaultForumFilter, setDefaultForumFilter,
    cardDensity,        setCardDensity,
    notificationPrefs,  setNotificationPrefs,
    notificationSound,  setNotificationSound,
    isLoading,
  }), [
    announcementLevel, defaultForumFilter, cardDensity,
    notificationPrefs, notificationSound, isLoading,
    setAnnouncementLevel, setDefaultForumFilter, setCardDensity,
    setNotificationPrefs, setNotificationSound,
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
