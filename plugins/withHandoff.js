/**
 * Config plugin: Handoff (NSUserActivity)
 *
 * Copies the AppleVisHandoff native module into the main app target and
 * registers every activity type advertised by useHandoff() call sites in
 * Info.plist's NSUserActivityTypes — an activity type not listed there is
 * silently dropped by the system and never appears on nearby devices.
 */
const { withInfoPlist, withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');
const { addNativeModuleSources } = require('./lib/addNativeModuleSources');

const ACTIVITY_TYPES = [
  'com.applevis.app.viewHome',
  'com.applevis.app.viewForums',
  'com.applevis.app.viewApps',
  'com.applevis.app.viewApp',
  'com.applevis.app.viewPodcasts',
  'com.applevis.app.playEpisode',
  'com.applevis.app.viewResources',
  'com.applevis.app.viewResource',
  'com.applevis.app.viewBlog',
  'com.applevis.app.viewTopic',
  'com.applevis.app.bug',
  'com.applevis.app.discover',
  'com.applevis.app.forYou',
];

const withHandoff = (config) => {
  config = withInfoPlist(config, (cfg) => {
    const existing = cfg.modResults.NSUserActivityTypes ?? [];
    const merged = Array.from(new Set([...existing, ...ACTIVITY_TYPES]));
    cfg.modResults.NSUserActivityTypes = merged;
    return cfg;
  });

  config = withDangerousMod(config, ['ios', (cfg) => {
    const src  = path.join(cfg.modRequest.projectRoot, 'ios-native', 'Handoff');
    const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
    if (fs.existsSync(src)) {
      fs.readdirSync(src).forEach((file) => {
        fs.copyFileSync(path.join(src, file), path.join(dest, file));
      });
    }
    return cfg;
  }]);

  config = withXcodeProject(config, (cfg) => {
    addNativeModuleSources(cfg.modResults, cfg.modRequest.projectRoot, cfg.modRequest.projectName, 'Handoff');
    return cfg;
  });

  return config;
};

module.exports = withHandoff;
