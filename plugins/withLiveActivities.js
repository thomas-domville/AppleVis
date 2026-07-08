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
const { addTargetDependency } = require('./lib/ensureTargetDependency');

const EXT_TARGET  = 'AppleVisLiveActivity';
const EXT_BUNDLE  = 'com.applevis.app.liveactivity';
const SWIFT_VER   = '5.9';

// ─── helpers ─────────────────────────────────────────────────────────────────

function addExtensionTarget(xcodeProject, targetName, bundleId, swiftFiles, marketingVersion, projectVersion) {
  if (xcodeProject.pbxTargetByName(targetName)) return; // already added

  const target = xcodeProject.addTarget(targetName, 'app_extension', targetName, bundleId);

  // addTarget() creates the target with empty buildPhases. Without its own
  // Sources/Frameworks phases, addSourceFile()/addFramework() below fall back
  // to the first matching phase found anywhere in the project — the main
  // app's — silently compiling this target's files into the main app instead.
  xcodeProject.addBuildPhase([], 'PBXSourcesBuildPhase', 'Sources', target.uuid);
  xcodeProject.addBuildPhase([], 'PBXFrameworksBuildPhase', 'Frameworks', target.uuid);

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
      // addTarget() defaults this to "<target>/<target>-Info.plist", but we
      // write the file as plain "Info.plist" — correct it to match.
      cfg.buildSettings.INFOPLIST_FILE                  = `"${targetName}/Info.plist"`;
      // App Store requires an extension's CFBundleShortVersionString to
      // match its containing app's exactly — keep these in lockstep with
      // the main target instead of the default "1.0"/"1".
      cfg.buildSettings.MARKETING_VERSION               = marketingVersion;
      cfg.buildSettings.CURRENT_PROJECT_VERSION         = projectVersion;
      // The .entitlements file is written to disk (below) but Xcode only
      // actually applies it during signing if this build setting points at
      // it — without it the extension builds and signs fine but has no App
      // Group access at runtime, so shared UserDefaults reads silently fail.
      cfg.buildSettings.CODE_SIGN_ENTITLEMENTS          = `"${targetName}/${targetName}.entitlements"`;
    }
  });

  // Frameworks
  xcodeProject.addFramework('WidgetKit.framework',  { target: target.uuid });
  xcodeProject.addFramework('SwiftUI.framework',    { target: target.uuid });
  xcodeProject.addFramework('ActivityKit.framework',{ target: target.uuid });

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

  // Source files
  swiftFiles.forEach((f) => {
    xcodeProject.addSourceFile(path.basename(f), { target: target.uuid }, groupKey);
  });

  // Belt-and-suspenders: addTarget() is documented to add this dependency
  // itself, but that isn't reliably landing in the generated project —
  // add it explicitly so Xcode's build system has a guaranteed ordering
  // edge for the embed phase above.
  addTargetDependency(xcodeProject, xcodeProject.getFirstTarget().uuid, [target.uuid]);
}

// The dangerousMod step below copies the controller files onto disk next to
// the main app's own source files, but a file that isn't registered in the
// Xcode project's Sources build phase for a target simply never compiles —
// it's silently ignored, not an error. Register them for the main target
// here (it already has its own Sources phase, unlike a freshly created one).
function addMainTargetSourceFiles(xcodeProject, projectRoot, projectName) {
  const nativeSrc = path.join(projectRoot, 'ios-native', 'LiveActivity');
  if (!fs.existsSync(nativeSrc)) return;

  const mainTarget = xcodeProject.getFirstTarget();
  const mainGroupKey = xcodeProject.getFirstProject().firstProject.mainGroup;

  fs.readdirSync(nativeSrc).forEach((file) => {
    if (file === 'AppleVisLiveActivity.swift') return; // goes into the extension target instead
    xcodeProject.addSourceFile(`${projectName}/${file}`, { target: mainTarget.uuid }, mainGroupKey);
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
    // Needs the full standard bundle key set (matching Xcode's own widget
    // extension template) — a bare NSExtension-only plist compiles and
    // signs fine, but the AppIntentsSSUTraining build tool fails to parse
    // it ("Unable to parse Info.plist") without CFBundlePackageType et al.
    const infoPlistPath = path.join(extDir, 'Info.plist');
    if (!fs.existsSync(infoPlistPath)) {
      fs.writeFileSync(infoPlistPath, `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${EXT_TARGET}</string>
  <key>CFBundleExecutable</key>
  <string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIdentifier</key>
  <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$(PRODUCT_NAME)</string>
  <key>CFBundlePackageType</key>
  <string>XPC!</string>
  <key>CFBundleShortVersionString</key>
  <string>$(MARKETING_VERSION)</string>
  <key>CFBundleVersion</key>
  <string>$(CURRENT_PROJECT_VERSION)</string>
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
      cfg.version ?? '1.0',
      cfg.ios?.buildNumber ?? '1',
    );
    addMainTargetSourceFiles(cfg.modResults, cfg.modRequest.projectRoot, cfg.modRequest.projectName);
    return cfg;
  });

  return config;
};

module.exports = withLiveActivities;
