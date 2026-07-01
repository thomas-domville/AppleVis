const config = {
  name: 'AppleVis',
  slug: 'applevis',
  version: '2026.0.6',
  orientation: 'default',
  icon: './assets/icons/app-icon.png',
  scheme: 'applevis',
  userInterfaceStyle: 'automatic',
  newArchEnabled: true,

  splash: {
    image: './assets/images/splash.png',
    resizeMode: 'contain',
    backgroundColor: '#0A84FF',
  },

  ios: {
    icon: {
      any:    './assets/icons/app-icon.png',
      dark:   './assets/icons/app-icon-dark.png',
      tinted: './assets/icons/app-icon-tinted.png',
    },
    supportsTablet: true,
    bundleIdentifier: 'com.applevis.app',
    buildNumber: '10',
    minimumOsVersion: '16.0',
    usesNonExemptEncryption: false,
    requireFullScreen: false,
    associatedDomains: [
      'applinks:www.applevis.com',
      'applinks:applevis.com',
    ],
    entitlements: {
      'com.apple.security.application-groups': ['group.com.applevis.app'],
      'com.apple.developer.siri': true,
    },
    infoPlist: {
      UIBackgroundModes: ['audio', 'remote-notification', 'fetch', 'processing'],
      NSMicrophoneUsageDescription:
        'Required by the audio framework used for podcast playback. AppleVis does not record audio.',
      NSUserTrackingUsageDescription:
        'AppleVis does not track you across apps or websites.',
      NSSiriUsageDescription:
        'Use Siri to open forums, play podcasts, and check what is new on AppleVis.',
      NSSupportsLiveActivities: true,
      NSSupportsLiveActivitiesFrequentUpdates: true,
      CFBundleLocalizations: [
        'en', 'es', 'fr', 'de', 'pt', 'it', 'ja', 'ko', 'nl',
        'zh-Hans', 'ar', 'fa', 'hi',
      ],
      NSUserActivityTypes: [
        'com.applevis.app.viewForums',
        'com.applevis.app.viewApps',
        'com.applevis.app.viewPodcasts',
        'com.applevis.app.viewResources',
        'com.applevis.app.viewTopic',
        'com.applevis.app.viewApp',
        'com.applevis.app.playEpisode',
        'com.applevis.app.viewResource',
      ],
    },
  },

  android: {
    package: 'com.applevis.app',
    versionCode: 3,
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
    'expo-notifications',
    'expo-secure-store',
    'expo-background-fetch',
    'expo-task-manager',
    './plugins/withPrivacyManifest',
    './plugins/withNowPlaying',
    './plugins/withiCloudKVS',
    './plugins/withLiveActivities',
    './plugins/withWidgetKit',
    './plugins/withSpotlight',
    './plugins/withIntelligence',
    './plugins/withSiri',
    './plugins/withRoutePicker',
    './plugins/withAudioEffects',
    './plugins/withCarPlay',
    [
      'expo-build-properties',
      {
        ios: {
          privacyManifests: {
            NSPrivacyAccessedAPITypes: [
              {
                NSPrivacyAccessedAPIType: 'NSPrivacyAccessedAPICategoryUserDefaults',
                NSPrivacyAccessedAPITypeReasons: ['CA92.1'],
              },
              {
                NSPrivacyAccessedAPIType: 'NSPrivacyAccessedAPICategoryFileTimestamp',
                NSPrivacyAccessedAPITypeReasons: ['C617.1', '0A2A.1'],
              },
              {
                NSPrivacyAccessedAPIType: 'NSPrivacyAccessedAPICategoryDiskSpace',
                NSPrivacyAccessedAPITypeReasons: ['85F4.1'],
              },
              {
                NSPrivacyAccessedAPIType: 'NSPrivacyAccessedAPICategorySystemBootTime',
                NSPrivacyAccessedAPITypeReasons: ['35F9.1'],
              },
            ],
          },
        },
      },
    ],
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
