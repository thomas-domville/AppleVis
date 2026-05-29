const config = {
  name: 'AppleVis',
  slug: 'applevis',
  version: '2026.1.0',
  orientation: 'default',
  icon: './assets/icons/app-icon.png',
  scheme: 'applevis',
  userInterfaceStyle: 'automatic',

  splash: {
    image: './assets/images/splash.png',
    resizeMode: 'contain',
    backgroundColor: '#0A84FF',
  },

  ios: {
    supportsTablet: true,
    bundleIdentifier: 'com.applevis.app',
    buildNumber: '1',
    requireFullScreen: false,
    infoPlist: {
      // Background modes
      UIBackgroundModes: ['audio', 'remote-notification', 'fetch', 'processing'],
      // Privacy descriptions
      NSMicrophoneUsageDescription:
        'AppleVis does not record audio. Required only if future voice features are added.',
      NSUserTrackingUsageDescription:
        'AppleVis does not track you across apps or websites.',
      // Live Activities
      NSSupportsLiveActivities: true,
      NSSupportsLiveActivitiesFrequentUpdates: true,
      // Siri
      NSSiriUsageDescription: 'Use Siri to control AppleVis podcast playback and check your forums.',
    },
    entitlements: {
      // App Groups — shared between main app, widget, and watch
      'com.apple.security.application-groups': ['group.com.applevis.app'],
      // Siri
      'com.apple.developer.siri': true,
    },
    associatedDomains: ['applinks:www.applevis.com'],
  },

  android: {
    package: 'com.applevis.app',
    versionCode: 1,
    adaptiveIcon: {
      foregroundImage: './assets/icons/app-icon.png',
      backgroundColor: '#0A84FF',
    },
    permissions: ['FOREGROUND_SERVICE', 'RECEIVE_BOOT_COMPLETED'],
  },

  web: {
    bundler: 'metro',
    output: 'static',
    favicon: './assets/icons/app-icon.png',
  },

  plugins: [
    'expo-router',
    'expo-av',
    // Notification sounds are loaded at runtime via expo-av; sound files with spaces
    // in their names cannot be registered as Android resources.
    'expo-notifications',
    'expo-secure-store',
    'expo-background-fetch',
    'expo-task-manager',
    // Custom native config plugins
    './plugins/withNowPlaying',
    './plugins/withWidgetKit',
    './plugins/withLiveActivities',
  ],

  experiments: {
    typedRoutes: true,
  },

  extra: {
    eas: {
      projectId: 'applevis-2026',
    },
  },
};

export default config;
