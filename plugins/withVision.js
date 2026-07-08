/**
 * Config plugin: Vision framework image description
 *
 * Copies the AppleVisVision native module into the main app target during
 * prebuild. Vision is a system framework — no extra entitlement or
 * Info.plist key is required.
 */
const { withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');
const { addNativeModuleSources } = require('./lib/addNativeModuleSources');

const withVision = (config) => {
  config = withDangerousMod(config, ['ios', (cfg) => {
    const src  = path.join(cfg.modRequest.projectRoot, 'ios-native', 'Vision');
    const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
    if (fs.existsSync(src)) {
      fs.readdirSync(src).forEach((file) => {
        fs.copyFileSync(path.join(src, file), path.join(dest, file));
      });
    }
    return cfg;
  }]);

  config = withXcodeProject(config, (cfg) => {
    addNativeModuleSources(cfg.modResults, cfg.modRequest.projectRoot, cfg.modRequest.projectName, 'Vision');
    return cfg;
  });

  return config;
};

module.exports = withVision;
