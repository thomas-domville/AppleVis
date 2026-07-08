/**
 * Config plugin: Apple Watch companion app
 *
 * Uses the classic two-target WatchKit2 structure (a thin "watch app"
 * container + a separate "watch extension" holding the actual SwiftUI
 * code) rather than the newer single-target watchOS model, because the
 * `xcode` npm package this project's other extension-target plugins rely
 * on (see withWidgetKit.js / withLiveActivities.js) only ships built-in
 * support for the two-target shape (`addTarget(..., 'watch2_app', ...)` /
 * `'watch2_extension'`). Apple still fully supports this structure for
 * existing apps — it's just no longer what a brand-new Xcode project
 * scaffolds by default. Migrating to the single-target model later is a
 * one-time manual step in Xcode if desired (Product ▸ ... ▸ Migrate).
 *
 * AppleVisWatchApp.swift itself needs no changes either way — a SwiftUI
 * `@main App` works as the extension's entry point in both structures.
 *
 * 1. Creates the AppleVisWatch (watch2_app) target — a thin container with
 *    just an Info.plist. addTarget() auto-embeds it into the main iOS app
 *    ("Embed Watch Content" copy-files phase + target dependency).
 * 2. Creates the AppleVisWatchExtension (watch2_extension) target, copies
 *    AppleVisWatchApp.swift into it, links WatchKit/SwiftUI/WatchConnectivity.
 *    addTarget() auto-embeds it into AppleVisWatch.
 * 3. Copies AppleVisWatchConnectivity.swift/.m — the phone-side
 *    WCSessionDelegate bridge — into the MAIN app target (it's a normal
 *    RCTEventEmitter module, not part of either watch target).
 *
 * No entitlements are needed on either watch target — WatchConnectivity's
 * message-passing APIs don't require an App Group.
 */
const { withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');
const { addNativeModuleSources } = require('./lib/addNativeModuleSources');
const { addTargetDependency } = require('./lib/ensureTargetDependency');

const APP_TARGET      = 'AppleVisWatch';
const APP_BUNDLE      = 'com.applevis.app.watchkitapp';
const EXT_TARGET      = 'AppleVisWatchExtension';
const EXT_BUNDLE      = 'com.applevis.app.watchkitapp.watchkitextension';
const SWIFT_VER        = '5.9';
const WATCHOS_MIN      = '9.0';

function applyCommonBuildSettings(xcodeProject, targetName, bundleId, marketingVersion, projectVersion, extra) {
  const configs = xcodeProject.pbxXCBuildConfigurationSection();
  Object.values(configs).forEach((cfg) => {
    if (typeof cfg !== 'object' || !cfg.buildSettings) return;
    if (cfg.buildSettings.PRODUCT_NAME === `"${targetName}"` ||
        cfg.buildSettings.PRODUCT_BUNDLE_IDENTIFIER === `"${bundleId}"`) {
      cfg.buildSettings.SDKROOT                    = 'watchos';
      cfg.buildSettings.SUPPORTED_PLATFORMS        = '"watchsimulator watchos"';
      cfg.buildSettings.TARGETED_DEVICE_FAMILY     = '4';
      cfg.buildSettings.WATCHOS_DEPLOYMENT_TARGET  = WATCHOS_MIN;
      cfg.buildSettings.PRODUCT_BUNDLE_IDENTIFIER  = `"${bundleId}"`;
      cfg.buildSettings.SKIP_INSTALL               = 'YES';
      // addTarget() defaults this to "<target>/<target>-Info.plist", but we
      // write the file as plain "Info.plist" — correct it to match.
      cfg.buildSettings.INFOPLIST_FILE             = `"${targetName}/Info.plist"`;
      // App Store requires an embedded watch app/extension's
      // CFBundleShortVersionString to match the containing app's exactly.
      cfg.buildSettings.MARKETING_VERSION           = marketingVersion;
      cfg.buildSettings.CURRENT_PROJECT_VERSION     = projectVersion;
      Object.assign(cfg.buildSettings, extra);
    }
  });
}

const withWatch = (config) => {
  // Write Info.plists + copy the extension's Swift source onto disk
  config = withDangerousMod(config, ['ios', (cfg) => {
    const iosRoot = cfg.modRequest.platformProjectRoot;
    const appDir  = path.join(iosRoot, APP_TARGET);
    const extDir  = path.join(iosRoot, EXT_TARGET);
    if (!fs.existsSync(appDir)) fs.mkdirSync(appDir, { recursive: true });
    if (!fs.existsSync(extDir)) fs.mkdirSync(extDir, { recursive: true });

    const mainBundleId = cfg.ios?.bundleIdentifier ?? 'com.applevis.app';

    // Watch app container Info.plist
    const appPlistPath = path.join(appDir, 'Info.plist');
    if (!fs.existsSync(appPlistPath)) {
      fs.writeFileSync(appPlistPath, `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIdentifier</key>
  <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_TARGET}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$(MARKETING_VERSION)</string>
  <key>CFBundleVersion</key>
  <string>$(CURRENT_PROJECT_VERSION)</string>
  <key>WKWatchKitApp</key>
  <true/>
  <key>WKCompanionAppBundleIdentifier</key>
  <string>${mainBundleId}</string>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
  </array>
</dict>
</plist>`);
    }

    // Watch extension Info.plist
    const extPlistPath = path.join(extDir, 'Info.plist');
    if (!fs.existsSync(extPlistPath)) {
      fs.writeFileSync(extPlistPath, `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIdentifier</key>
  <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${EXT_TARGET}</string>
  <key>CFBundlePackageType</key>
  <string>XPC!</string>
  <key>CFBundleShortVersionString</key>
  <string>$(MARKETING_VERSION)</string>
  <key>CFBundleVersion</key>
  <string>$(CURRENT_PROJECT_VERSION)</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionAttributes</key>
    <dict>
      <key>WKAppBundleIdentifier</key>
      <string>${APP_BUNDLE}</string>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.watchkit</string>
  </dict>
</dict>
</plist>`);
    }

    const nativeSrc = path.join(cfg.modRequest.projectRoot, 'ios-native', 'Watch');
    const mainAppDir = path.join(iosRoot, cfg.modRequest.projectName);
    if (fs.existsSync(nativeSrc)) {
      fs.readdirSync(nativeSrc).forEach((file) => {
        const dest = file === 'AppleVisWatchApp.swift'
          ? path.join(extDir, file)     // watch UI            → watch extension target
          : path.join(mainAppDir, file); // WatchConnectivity bridge → main app target
        fs.copyFileSync(path.join(nativeSrc, file), dest);
      });
    }

    return cfg;
  }]);

  // Register both targets in the .pbxproj
  config = withXcodeProject(config, (cfg) => {
    const xcodeProject = cfg.modResults;
    const marketingVersion = cfg.version ?? '1.0';
    const projectVersion   = cfg.ios?.buildNumber ?? '1';

    let appTarget = null;
    if (!xcodeProject.pbxTargetByName(APP_TARGET)) {
      appTarget = xcodeProject.addTarget(APP_TARGET, 'watch2_app', APP_TARGET, APP_BUNDLE);
      applyCommonBuildSettings(xcodeProject, APP_TARGET, APP_BUNDLE, marketingVersion, projectVersion, {});
      // Belt-and-suspenders: addTarget() is documented to add this
      // dependency itself, but that isn't reliably landing in the
      // generated project — add it explicitly for a guaranteed build-order
      // edge on the "Embed Watch Content" phase above.
      addTargetDependency(xcodeProject, xcodeProject.getFirstTarget().uuid, [appTarget.uuid]);
    }

    if (appTarget && !xcodeProject.pbxTargetByName(EXT_TARGET)) {
      const extTarget = xcodeProject.addTarget(EXT_TARGET, 'watch2_extension', EXT_TARGET, EXT_BUNDLE);
      applyCommonBuildSettings(xcodeProject, EXT_TARGET, EXT_BUNDLE, marketingVersion, projectVersion, {
        SWIFT_VERSION: SWIFT_VER,
      });

      addTargetDependency(xcodeProject, appTarget.uuid, [extTarget.uuid]);

      // addTarget() creates the target with empty buildPhases — without its
      // own Sources/Frameworks phases, addSourceFile()/addFramework() below
      // fall back to the first matching phase found anywhere in the
      // project (the main app's), silently compiling this target's files
      // into the main app instead.
      xcodeProject.addBuildPhase([], 'PBXSourcesBuildPhase', 'Sources', extTarget.uuid);
      xcodeProject.addBuildPhase([], 'PBXFrameworksBuildPhase', 'Frameworks', extTarget.uuid);

      xcodeProject.addFramework('SwiftUI.framework', { target: extTarget.uuid });
      xcodeProject.addFramework('WatchKit.framework', { target: extTarget.uuid });
      xcodeProject.addFramework('WatchConnectivity.framework', { target: extTarget.uuid });

      // addSourceFile() falls back to addPluginFile() when no group is
      // given, which requires a "Plugins" PBXGroup that doesn't exist in a
      // fresh prebuild project and throws. Create a real group instead.
      const groupKey = xcodeProject.pbxCreateGroup(EXT_TARGET, EXT_TARGET);
      const mainGroupKey = xcodeProject.getFirstProject().firstProject.mainGroup;
      const mainGroup = xcodeProject.getPBXGroupByKey(mainGroupKey);
      if (mainGroup) {
        mainGroup.children.push({ value: groupKey, comment: EXT_TARGET });
      }

      xcodeProject.addSourceFile('AppleVisWatchApp.swift', { target: extTarget.uuid }, groupKey);
    }

    addNativeModuleSources(xcodeProject, cfg.modRequest.projectRoot, cfg.modRequest.projectName, 'Watch', {
      exclude: ['AppleVisWatchApp.swift'],
    });

    return cfg;
  });

  return config;
};

module.exports = withWatch;
