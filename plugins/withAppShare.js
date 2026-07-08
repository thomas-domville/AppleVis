/**
 * Config plugin: App Share consumer
 *
 * Copies the AppleVisAppShare native module into the main app target and
 * adds the shared App Group entitlement so it can read the pending
 * URL/text values written by the Share Extension.
 */
const { withEntitlementsPlist, withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');
const { addNativeModuleSources } = require('./lib/addNativeModuleSources');

const APP_GROUP = 'group.com.applevis.app';

const withAppShare = (config) => {
  config = withEntitlementsPlist(config, (cfg) => {
    const groups = cfg.modResults['com.apple.security.application-groups'] ?? [];
    if (!groups.includes(APP_GROUP)) {
      cfg.modResults['com.apple.security.application-groups'] = [...groups, APP_GROUP];
    }
    return cfg;
  });

  config = withDangerousMod(config, ['ios', (cfg) => {
    const src  = path.join(cfg.modRequest.projectRoot, 'ios-native', 'AppShare');
    const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
    if (fs.existsSync(src)) {
      fs.readdirSync(src).forEach((file) => {
        fs.copyFileSync(path.join(src, file), path.join(dest, file));
      });
    }
    return cfg;
  }]);

  config = withXcodeProject(config, (cfg) => {
    addNativeModuleSources(cfg.modResults, cfg.modRequest.projectRoot, cfg.modRequest.projectName, 'AppShare');
    return cfg;
  });

  return config;
};

module.exports = withAppShare;
