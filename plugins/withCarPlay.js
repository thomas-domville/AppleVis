/**
 * Config plugin: CarPlay integration
 *
 * 1. Copies the CarPlay scene delegate Swift + ObjC bridge into Xcode.
 * 2. Adds the CPTemplateApplicationSceneSessionRoleApplication scene
 *    configuration to Info.plist so iOS presents the CarPlay scene.
 * 3. Adds the com.apple.developer.carplay-audio entitlement.
 *
 * After prebuild, open Xcode and:
 *   a) Add both CarPlay files to the main target's "Compile Sources".
 *   b) Enable the CarPlay capability in Signing & Capabilities.
 *   c) Request CarPlay entitlement from Apple (developer.apple.com/carplay).
 */
const { withInfoPlist, withEntitlementsPlist, withDangerousMod } = require('@expo/config-plugins');
const path = require('path');
const fs = require('fs');

const withCarPlay = (config) => {
  // Scene manifest entry for the CarPlay application scene
  config = withInfoPlist(config, (cfg) => {
    const manifest = cfg.modResults.UIApplicationSceneManifest ?? {};
    if (!manifest.UISceneConfigurations) manifest.UISceneConfigurations = {};
    const carPlayKey = 'CPTemplateApplicationSceneSessionRoleApplication';
    if (!manifest.UISceneConfigurations[carPlayKey]) {
      manifest.UISceneConfigurations[carPlayKey] = [
        {
          UISceneConfigurationName: 'AppleVis CarPlay Configuration',
          UISceneDelegateClassName: 'AppleVis.AppleVisCarPlaySceneDelegate',
        },
      ];
    }
    cfg.modResults.UIApplicationSceneManifest = manifest;
    return cfg;
  });

  // CarPlay audio entitlement
  config = withEntitlementsPlist(config, (cfg) => {
    cfg.modResults['com.apple.developer.carplay-audio'] = true;
    return cfg;
  });

  // Copy Swift + ObjC files into Xcode project
  config = withDangerousMod(config, [
    'ios',
    (cfg) => {
      const src  = path.join(cfg.modRequest.projectRoot, 'ios-native', 'CarPlay');
      const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
      if (!fs.existsSync(dest)) return cfg;
      for (const file of fs.readdirSync(src)) {
        fs.copyFileSync(path.join(src, file), path.join(dest, file));
      }
      return cfg;
    },
  ]);

  return config;
};

module.exports = withCarPlay;
