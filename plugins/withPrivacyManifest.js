/**
 * Expo config plugin — copies PrivacyInfo.xcprivacy into the iOS project.
 *
 * Apple requires a privacy manifest for all apps submitted to the App Store.
 * The file lives at assets/PrivacyInfo.xcprivacy and is copied into the
 * native iOS project during `expo prebuild` or EAS Build.
 *
 * References:
 *   https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
 *   https://docs.expo.dev/config-plugins/introduction/
 */

const { withDangerousMod } = require('@expo/config-plugins');
const fs   = require('fs');
const path = require('path');

/** @param {import('@expo/config-plugins').ExpoConfig} config */
function withPrivacyManifest(config) {
  return withDangerousMod(config, [
    'ios',
    (cfg) => {
      const projectRoot = cfg.modRequest.projectRoot;
      const projectName = cfg.modRequest.projectName ?? config.name;
      const src  = path.join(projectRoot, 'assets', 'PrivacyInfo.xcprivacy');
      const dest = path.join(projectRoot, 'ios', projectName, 'PrivacyInfo.xcprivacy');

      if (fs.existsSync(src)) {
        const iosDir = path.dirname(dest);
        if (!fs.existsSync(iosDir)) fs.mkdirSync(iosDir, { recursive: true });
        fs.copyFileSync(src, dest);
        console.log('[withPrivacyManifest] Copied PrivacyInfo.xcprivacy →', dest);
      } else {
        console.warn('[withPrivacyManifest] Source file not found:', src);
      }

      return cfg;
    },
  ]);
}

module.exports = withPrivacyManifest;
