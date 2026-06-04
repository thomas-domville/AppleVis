/**
 * Config plugin: WidgetKit Home/Lock Screen Widgets
 *
 * 1. Adds the App Group entitlement to the main app.
 * 2. Copies the widget data-writer (main-app side) into ios/AppleVis/.
 * 3. Creates the AppleVisWidget extension target directory and copies the UI Swift file.
 * 4. Registers the extension target in the Xcode project file.
 */
const { withEntitlementsPlist, withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');

const EXT_TARGET  = 'AppleVisWidget';
const EXT_BUNDLE  = 'com.applevis.app.widget';
const SWIFT_VER   = '5.9';
const APP_GROUP   = 'group.com.applevis.app';

function addExtensionTarget(xcodeProject, targetName, bundleId, swiftFiles) {
  if (xcodeProject.pbxTargetByName(targetName)) return;

  const target = xcodeProject.addTarget(targetName, 'app_extension', targetName, bundleId);

  const configs = xcodeProject.pbxXCBuildConfigurationSection();
  Object.values(configs).forEach((cfg) => {
    if (typeof cfg !== 'object' || !cfg.buildSettings) return;
    if (cfg.buildSettings.PRODUCT_NAME === `"${targetName}"` ||
        cfg.buildSettings.PRODUCT_BUNDLE_IDENTIFIER === `"${bundleId}"`) {
      cfg.buildSettings.SWIFT_VERSION              = SWIFT_VER;
      cfg.buildSettings.IPHONEOS_DEPLOYMENT_TARGET = '16.0';
      cfg.buildSettings.TARGETED_DEVICE_FAMILY     = '"1,2"';
      cfg.buildSettings.PRODUCT_BUNDLE_IDENTIFIER  = `"${bundleId}"`;
      cfg.buildSettings.SKIP_INSTALL               = 'YES';
    }
  });

  xcodeProject.addFramework('WidgetKit.framework', { target: target.uuid });
  xcodeProject.addFramework('SwiftUI.framework',   { target: target.uuid });

  swiftFiles.forEach((f) => {
    xcodeProject.addSourceFile(`${targetName}/${path.basename(f)}`, { target: target.uuid });
  });
}

const withWidgetKit = (config) => {
  // App Group entitlement on main app
  config = withEntitlementsPlist(config, (cfg) => {
    const groups = cfg.modResults['com.apple.security.application-groups'] ?? [];
    if (!groups.includes(APP_GROUP)) {
      cfg.modResults['com.apple.security.application-groups'] = [...groups, APP_GROUP];
    }
    return cfg;
  });

  // Copy files
  config = withDangerousMod(config, ['ios', (cfg) => {
    const root      = cfg.modRequest.projectRoot;
    const iosRoot   = cfg.modRequest.platformProjectRoot;
    const appTarget = path.join(iosRoot, cfg.modRequest.projectName);
    const extDir    = path.join(iosRoot, EXT_TARGET);

    if (!fs.existsSync(extDir)) fs.mkdirSync(extDir, { recursive: true });

    const nativeSrc = path.join(root, 'ios-native', 'Widget');
    if (fs.existsSync(nativeSrc)) {
      fs.readdirSync(nativeSrc).forEach((file) => {
        const dest = file === 'AppleVisWidget.swift'
          ? path.join(extDir, file)      // extension UI → extension target
          : path.join(appTarget, file);  // data writer  → main target
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

    // Extension entitlements (needs the same App Group to read shared UserDefaults)
    const entPath = path.join(extDir, `${EXT_TARGET}.entitlements`);
    if (!fs.existsSync(entPath)) {
      fs.writeFileSync(entPath, `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>${APP_GROUP}</string>
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
      [`${EXT_TARGET}/AppleVisWidget.swift`],
    );
    return cfg;
  });

  return config;
};

module.exports = withWidgetKit;
