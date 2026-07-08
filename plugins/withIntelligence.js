/**
 * Config plugin: Foundation Models (Apple Intelligence)
 *
 * Copies AppleVisIntelligence.swift and AppleVisIntelligence.m into the main
 * app target during prebuild. The module is a standard RCT bridge module, so
 * no extension target or special entitlement is needed — Foundation Models is
 * available to any app on iOS 26+ when Apple Intelligence is enabled.
 */
const { withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');
const { addNativeModuleSources } = require('./lib/addNativeModuleSources');

const withIntelligence = (config) => {
  config = withDangerousMod(config, ['ios', (cfg) => {
    const src  = path.join(cfg.modRequest.projectRoot, 'ios-native', 'Intelligence');
    const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
    if (fs.existsSync(src)) {
      fs.readdirSync(src).forEach((file) => {
        fs.copyFileSync(path.join(src, file), path.join(dest, file));
      });
    }
    return cfg;
  }]);

  config = withXcodeProject(config, (cfg) => {
    addNativeModuleSources(cfg.modResults, cfg.modRequest.projectRoot, cfg.modRequest.projectName, 'Intelligence');
    return cfg;
  });

  return config;
};

module.exports = withIntelligence;
