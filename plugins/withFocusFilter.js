/**
 * Config plugin: Focus Filter (SetFocusFilterIntent)
 *
 * Copies the AppleVisFocusFilterIntent AppIntent into the main app target.
 * iOS discovers SetFocusFilterIntent conformers automatically once compiled
 * in — no Info.plist registration or JS bridge is needed.
 */
const { withEntitlementsPlist, withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');
const { addNativeModuleSources } = require('./lib/addNativeModuleSources');

const APP_GROUP = 'group.com.applevis.app';

const withFocusFilter = (config) => {
  config = withEntitlementsPlist(config, (cfg) => {
    const groups = cfg.modResults['com.apple.security.application-groups'] ?? [];
    if (!groups.includes(APP_GROUP)) {
      cfg.modResults['com.apple.security.application-groups'] = [...groups, APP_GROUP];
    }
    return cfg;
  });

  config = withDangerousMod(config, ['ios', (cfg) => {
    const src  = path.join(cfg.modRequest.projectRoot, 'ios-native', 'FocusFilter');
    const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
    if (fs.existsSync(src)) {
      fs.readdirSync(src).forEach((file) => {
        fs.copyFileSync(path.join(src, file), path.join(dest, file));
      });
    }
    return cfg;
  }]);

  config = withXcodeProject(config, (cfg) => {
    addNativeModuleSources(cfg.modResults, cfg.modRequest.projectRoot, cfg.modRequest.projectName, 'FocusFilter');
    return cfg;
  });

  return config;
};

module.exports = withFocusFilter;
