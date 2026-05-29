/**
 * Config plugin: iCloud Key-Value Store
 *
 * Adds the iCloud KVS entitlement and copies the AppleVisCloudSync Swift
 * bridge files into the generated iOS project during prebuild.
 *
 * The iCloud KVS entitlement (com.apple.developer.ubiquitous-kvstore-identifier)
 * must also be enabled in the Apple Developer portal under the App ID capabilities.
 */
const { withEntitlementsPlist, withDangerousMod } = require('@expo/config-plugins');
const path = require('path');
const fs = require('fs');

const withiCloudKVS = (config) => {
  // Add iCloud KVS entitlement
  config = withEntitlementsPlist(config, (cfg) => {
    const appId = cfg.ios?.bundleIdentifier ?? 'com.applevis.app';
    cfg.modResults['com.apple.developer.ubiquitous-kvstore-identifier'] = appId;
    return cfg;
  });

  // Copy Swift bridge source into ios/ during prebuild
  config = withDangerousMod(config, [
    'ios',
    (cfg) => {
      const src = path.join(cfg.modRequest.projectRoot, 'ios-native', 'CloudSync');
      const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
      if (fs.existsSync(src)) {
        fs.readdirSync(src).forEach((file) => {
          fs.copyFileSync(path.join(src, file), path.join(dest, file));
        });
      }
      return cfg;
    },
  ]);

  return config;
};

module.exports = withiCloudKVS;
