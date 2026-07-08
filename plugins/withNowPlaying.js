/**
 * Config plugin: MPRemoteCommandCenter + Now Playing
 *
 * Ensures UIBackgroundModes contains 'audio' and wires in the
 * AppleVisNowPlaying native module source so that Lock Screen controls,
 * Control Center, AirPlay, and headphone buttons work.
 *
 * After `npx expo prebuild`, copy ios-native/NowPlaying/ files into the
 * generated ios/<AppName>/ folder in Xcode and add them to the main target.
 */
const { withInfoPlist, withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs = require('fs');
const { addNativeModuleSources } = require('./lib/addNativeModuleSources');

const withNowPlaying = (config) => {
  // Ensure background audio mode
  config = withInfoPlist(config, (cfg) => {
    if (!cfg.modResults.UIBackgroundModes) cfg.modResults.UIBackgroundModes = [];
    if (!cfg.modResults.UIBackgroundModes.includes('audio')) {
      cfg.modResults.UIBackgroundModes.push('audio');
    }
    return cfg;
  });

  // Copy Swift bridge source into ios/ during prebuild
  config = withDangerousMod(config, [
    'ios',
    (cfg) => {
      const src = path.join(cfg.modRequest.projectRoot, 'ios-native', 'NowPlaying');
      const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
      if (fs.existsSync(src)) {
        const files = fs.readdirSync(src);
        files.forEach((file) => {
          fs.copyFileSync(path.join(src, file), path.join(dest, file));
        });
      }
      return cfg;
    },
  ]);

  config = withXcodeProject(config, (cfg) => {
    addNativeModuleSources(cfg.modResults, cfg.modRequest.projectRoot, cfg.modRequest.projectName, 'NowPlaying');
    return cfg;
  });

  return config;
};

module.exports = withNowPlaying;
