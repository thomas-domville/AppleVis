/**
 * Config plugin: Live Activities + Dynamic Island
 *
 * 1. Sets NSSupportsLiveActivities Info.plist keys.
 * 2. Copies the main-app controller (start/update/end) into ios/AppleVis/.
 * 3. Creates the AppleVisLiveActivity widget-extension target directory and
 *    copies the extension UI Swift file into it.
 * 4. Registers the extension target in the Xcode project file.
 */
const { withInfoPlist, withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');

const EXT_TARGET  = 'AppleVisLiveActivity';
const EXT_BUNDLE  = 'com.applevis.app.liveactivity';
const SWIFT_VER   = '5.9';

// ─── helpers ─────────────────────────────────────────────────────────────────

function addExtensionTarget(xcodeProject, targetName, bundleId, swiftFiles) {
  if (xcodeProject.pbxTargetByName(targetName)) return; // already added

  const target = xcodeProject.addTarget(targetName, 'app_extension', targetName, bundleId);

  // Build settings
  const configs = xcodeProject.pbxXCBuildConfigurationSection();
  Object.values(configs).forEach((cfg) => {
    if (typeof cfg !== 'object' || !cfg.buildSettings) return;
    if (cfg.buildSettings.PRODUCT_NAME === `"${targetName}"` ||
        cfg.buildSettings.PRODUCT_BUNDLE_IDENTIFIER === `"${bundleId}"`) {
      cfg.buildSettings.SWIFT_VERSION                   = SWIFT_VER;
      cfg.buildSettings.IPHONEOS_DEPLOYMENT_TARGET      = '16.2';
      cfg.buildSettings.TARGETED_DEVICE_FAMILY          = '"1,2"';
      cfg.buildSettings.PRODUCT_BUNDLE_IDENTIFIER       = `"${bundleId}"`;
      cfg.buildSettings.SKIP_INSTALL                    = 'YES';
    }
  });

  // Frameworks
  xcodeProject.addFramework('WidgetKit.framework',  { target: target.uuid });
  xcodeProject.addFramework('SwiftUI.framework',    { target: target.uuid });
  xcodeProject.addFramework('ActivityKit.framework',{ target: target.uuid });

  // Source files
  swiftFiles.forEach((f) => {
    xcodeProject.addSourceFile(`${targetName}/${path.basename(f)}`, { target: target.uuid });
  });
}

// ─── plugin ──────────────────────────────────────────────────────────────────

const withLiveActivities = (config) => {
  // Info.plist keys
  config = withInfoPlist(config, (cfg) => {
    cfg.modResults.NSSupportsLiveActivities              = true;
    cfg.modResults.NSSupportsLiveActivitiesFrequentUpdates = true;
    return cfg;
  });

  // Copy main-app controller files + extension UI file
  config = withDangerousMod(config, ['ios', (cfg) => {
    const root      = cfg.modRequest.projectRoot;
    const iosRoot   = cfg.modRequest.platformProjectRoot;
    const appTarget = path.join(iosRoot, cfg.modRequest.projectName);
    const extDir    = path.join(iosRoot, EXT_TARGET);

    if (!fs.existsSync(extDir)) fs.mkdirSync(extDir, { recursive: true });

    const nativeSrc = path.join(root, 'ios-native', 'LiveActivity');
    if (fs.existsSync(nativeSrc)) {
      fs.readdirSync(nativeSrc).forEach((file) => {
        const dest = file === 'AppleVisLiveActivity.swift'
          ? path.join(extDir, file)      // extension UI → extension target
          : path.join(appTarget, file);  // controller  → main target
        fs.copyFileSync(path.join(nativeSrc, file), dest);
      });
    }

    // Extension Info.plist
    const infoPlistPath = path.join(extDir, 'Info.plist');
    if (!fs.existsSync(infoPlistPath)) {
      fs.writeFileSync(infoPlistPath, `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
  </dict>
</dict>
</plist>`);
    }

    // Extension entitlements
    const entPath = path.join(extDir, `${EXT_TARGET}.entitlements`);
    if (!fs.existsSync(entPath)) {
      fs.writeFileSync(entPath, `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.com.applevis.app</string>
  </array>
</dict>
</plist>`);
    }

    return cfg;
  }]);

  // Register extension target in .pbxproj
  config = withXcodeProject(config, (cfg) => {
    addExtensionTarget(
      cfg.modResults,
      EXT_TARGET,
      EXT_BUNDLE,
      [`${EXT_TARGET}/AppleVisLiveActivity.swift`],
    );
    return cfg;
  });

  return config;
};

module.exports = withLiveActivities;
