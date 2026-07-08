/**
 * Config plugin: Siri App Intents
 *
 * Copies the AppleVisSiri.swift file (AppIntents + AppShortcutsProvider) into
 * the main app target during prebuild. AppIntents run in-process so no
 * extension target is needed. The Siri entitlement and NSSiriUsageDescription
 * are already set in app.config.ts.
 */
const { withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');
const { addNativeModuleSources } = require('./lib/addNativeModuleSources');

const withSiri = (config) => {
  config = withDangerousMod(config, ['ios', (cfg) => {
    const src  = path.join(cfg.modRequest.projectRoot, 'ios-native', 'Siri');
    const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
    if (fs.existsSync(src)) {
      fs.readdirSync(src).forEach((file) => {
        fs.copyFileSync(path.join(src, file), path.join(dest, file));
      });
    }
    return cfg;
  }]);

  config = withXcodeProject(config, (cfg) => {
    addNativeModuleSources(cfg.modResults, cfg.modRequest.projectRoot, cfg.modRequest.projectName, 'Siri');
    return cfg;
  });

  return config;
};

module.exports = withSiri;
