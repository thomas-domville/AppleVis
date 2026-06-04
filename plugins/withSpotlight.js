/**
 * Config plugin: CoreSpotlight indexing
 *
 * Copies the AppleVisSpotlight Swift + ObjC bridge files into the main app
 * target during prebuild so forum topics, podcast episodes, and app listings
 * appear in iOS system Search (swipe down from Home Screen).
 */
const { withDangerousMod } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');

const withSpotlight = (config) => {
  config = withDangerousMod(config, ['ios', (cfg) => {
    const src  = path.join(cfg.modRequest.projectRoot, 'ios-native', 'Spotlight');
    const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
    if (fs.existsSync(src)) {
      fs.readdirSync(src).forEach((file) => {
        fs.copyFileSync(path.join(src, file), path.join(dest, file));
      });
    }
    return cfg;
  }]);

  return config;
};

module.exports = withSpotlight;
