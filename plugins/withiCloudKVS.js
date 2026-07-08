/**
 * Config plugin: iCloud Key-Value Store
 *
 * Adds the iCloud KVS entitlement and copies the AppleVisCloudSync Swift
 * bridge files into the generated iOS project during prebuild.
 *
 * The iCloud KVS entitlement (com.apple.developer.ubiquity-kvstore-identifier)
 * must also be enabled in the Apple Developer portal under the App ID capabilities
 * (iCloud > Key-value storage) — EAS Build does not auto-sync this capability.
 */
const { withEntitlementsPlist, withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs = require('fs');
const { addNativeModuleSources } = require('./lib/addNativeModuleSources');

const withiCloudKVS = (config) => {
  // Add iCloud KVS entitlement
  config = withEntitlementsPlist(config, (cfg) => {
    const appId = cfg.ios?.bundleIdentifier ?? 'com.applevis.app';
    // Apple's provisioning profile stores this entitlement's value as
    // "<TeamID>.<bundleId>" — Xcode resolves these build variables at
    // sign time, so this stays correct across teams without hardcoding.
    cfg.modResults['com.apple.developer.ubiquity-kvstore-identifier'] = `$(TeamIdentifierPrefix)${appId}`;
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

  config = withXcodeProject(config, (cfg) => {
    addNativeModuleSources(cfg.modResults, cfg.modRequest.projectRoot, cfg.modRequest.projectName, 'CloudSync');
    return cfg;
  });

  return config;
};

module.exports = withiCloudKVS;
