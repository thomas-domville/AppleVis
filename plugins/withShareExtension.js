/**
 * Config plugin: Share Extension
 *
 * 1. Adds the App Group entitlement to the main app (already added by
 *    withAppShare, but this plugin doesn't depend on load order).
 * 2. Creates the AppleVisShareExtension target directory, copies the view
 *    controller Swift file and the pre-written Info.plist into it.
 * 3. Writes the extension's entitlements file (App Group, so it can write
 *    to the same shared UserDefaults suite AppleVisAppShare reads from).
 * 4. Registers the extension target in the Xcode project file.
 *
 * The extension shows no UI — it classifies the shared item, writes it to
 * shared storage, and deep-links back into the main app via the "applevis"
 * URL scheme (already registered from app.config.ts's `scheme` field).
 */
const { withEntitlementsPlist, withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');
const { addTargetDependency } = require('./lib/ensureTargetDependency');

const EXT_TARGET = 'AppleVisShareExtension';
const EXT_BUNDLE = 'com.applevis.app.shareextension';
const SWIFT_VER  = '5.9';
const APP_GROUP  = 'group.com.applevis.app';

function addExtensionTarget(xcodeProject, targetName, bundleId, swiftFiles, marketingVersion, projectVersion) {
  if (xcodeProject.pbxTargetByName(targetName)) return;

  const target = xcodeProject.addTarget(targetName, 'app_extension', targetName, bundleId);

  // addTarget() creates the target with empty buildPhases. Without its own
  // Sources/Frameworks phases, addSourceFile()/addFramework() below fall back
  // to the first matching phase found anywhere in the project — the main
  // app's — silently compiling this target's files into the main app instead.
  xcodeProject.addBuildPhase([], 'PBXSourcesBuildPhase', 'Sources', target.uuid);
  xcodeProject.addBuildPhase([], 'PBXFrameworksBuildPhase', 'Frameworks', target.uuid);

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
      // addTarget() defaults this to "<target>/<target>-Info.plist", but we
      // write the file as plain "Info.plist" — correct it to match.
      cfg.buildSettings.INFOPLIST_FILE             = `"${targetName}/Info.plist"`;
      // App Store requires an extension's CFBundleShortVersionString to
      // match its containing app's exactly — keep these in lockstep with
      // the main target instead of the default "1.0"/"1".
      cfg.buildSettings.MARKETING_VERSION          = marketingVersion;
      cfg.buildSettings.CURRENT_PROJECT_VERSION    = projectVersion;
      // The .entitlements file is written to disk (below) but Xcode only
      // actually applies it during signing if this build setting points at
      // it — without it the extension builds and signs fine but has no App
      // Group access at runtime, so shared UserDefaults writes silently fail.
      cfg.buildSettings.CODE_SIGN_ENTITLEMENTS     = `"${targetName}/${targetName}.entitlements"`;
    }
  });

  xcodeProject.addFramework('UniformTypeIdentifiers.framework', { target: target.uuid });

  // addSourceFile() falls back to addPluginFile() when no group is given,
  // which requires a "Plugins" PBXGroup that doesn't exist in a fresh
  // prebuild project and throws. Create a real group for the extension's
  // sources so it takes the addFile() path instead.
  const groupKey = xcodeProject.pbxCreateGroup(targetName, targetName);
  const mainGroupKey = xcodeProject.getFirstProject().firstProject.mainGroup;
  const mainGroup = xcodeProject.getPBXGroupByKey(mainGroupKey);
  if (mainGroup) {
    mainGroup.children.push({ value: groupKey, comment: targetName });
  }

  swiftFiles.forEach((f) => {
    xcodeProject.addSourceFile(path.basename(f), { target: target.uuid }, groupKey);
  });

  // Belt-and-suspenders: addTarget() is documented to add this dependency
  // itself for non-watch2_extension types, but that isn't reliably landing
  // in the generated project — add it explicitly so Xcode's build system
  // has a guaranteed ordering edge for the embed phase above.
  addTargetDependency(xcodeProject, xcodeProject.getFirstTarget().uuid, [target.uuid]);
}

const withShareExtension = (config) => {
  // App Group entitlement on main app (idempotent alongside withAppShare)
  config = withEntitlementsPlist(config, (cfg) => {
    const groups = cfg.modResults['com.apple.security.application-groups'] ?? [];
    if (!groups.includes(APP_GROUP)) {
      cfg.modResults['com.apple.security.application-groups'] = [...groups, APP_GROUP];
    }
    return cfg;
  });

  // Copy the view controller + Info.plist into the extension target directory
  config = withDangerousMod(config, ['ios', (cfg) => {
    const iosRoot = cfg.modRequest.platformProjectRoot;
    const extDir  = path.join(iosRoot, EXT_TARGET);
    if (!fs.existsSync(extDir)) fs.mkdirSync(extDir, { recursive: true });

    const nativeSrc = path.join(cfg.modRequest.projectRoot, 'ios-native', 'ShareExtension');
    if (fs.existsSync(nativeSrc)) {
      fs.readdirSync(nativeSrc).forEach((file) => {
        fs.copyFileSync(path.join(nativeSrc, file), path.join(extDir, file));
      });
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
      [`${EXT_TARGET}/AppleVisShareExtensionViewController.swift`],
      cfg.version ?? '1.0',
      cfg.ios?.buildNumber ?? '1',
    );
    return cfg;
  });

  return config;
};

module.exports = withShareExtension;
