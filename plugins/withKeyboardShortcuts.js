/**
 * Config plugin: iPadOS hardware keyboard shortcuts
 *
 * UIKit only consults the responder chain for keyCommands, and that chain
 * always terminates at UIApplication — so app-wide shortcuts that must fire
 * regardless of which view has focus need a UIApplication subclass, not an
 * RCTEventEmitter alone.
 *
 * (react-native/RCTKeyCommands looks like a shortcut for this, but its
 * implementation is compiled out entirely unless
 * `RCT_DEV && (TARGET_OS_SIMULATOR || TARGET_OS_MACCATALYST)` — on a real
 * iPad in a production build, sharedInstance returns nil and registration
 * is a silent no-op. Not usable here.)
 *
 * Expo's generated AppDelegate.swift uses `@UIApplicationMain`, which always
 * defaults the principal class to plain UIApplication with no way to
 * override it. This plugin swaps that attribute out for an explicit
 * main.swift that calls UIApplicationMain() with our own
 * AppleVisApplication principal class instead.
 */
const { withAppDelegate, withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');
const { addNativeModuleSources } = require('./lib/addNativeModuleSources');

const withKeyboardShortcuts = (config) => {
  config = withAppDelegate(config, (cfg) => {
    if (cfg.modResults.language !== 'swift') {
      throw new Error(
        'withKeyboardShortcuts: expected a Swift AppDelegate (found ' +
        cfg.modResults.language + '). This plugin only knows how to patch the Swift template.'
      );
    }
    const attr = '@UIApplicationMain';
    if (cfg.modResults.contents.includes(attr)) {
      cfg.modResults.contents = cfg.modResults.contents.replace(
        new RegExp(`${attr}\\s*\\n`),
        ''
      );
    } else if (!cfg.modResults.contents.includes('@main')) {
      // Neither attribute present — something upstream changed shape enough
      // that main.swift (which assumes AppDelegate has no synthesized entry
      // point of its own) could clash with it. Fail loudly rather than
      // silently produce a project with two competing entry points.
      throw new Error(
        'withKeyboardShortcuts: could not find @UIApplicationMain or @main in AppDelegate.swift — ' +
        'the Expo template shape has changed and this plugin needs updating.'
      );
    }
    return cfg;
  });

  config = withDangerousMod(config, ['ios', (cfg) => {
    const src  = path.join(cfg.modRequest.projectRoot, 'ios-native', 'KeyboardShortcuts');
    const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
    if (fs.existsSync(src)) {
      fs.readdirSync(src).forEach((file) => {
        fs.copyFileSync(path.join(src, file), path.join(dest, file));
      });
    }
    return cfg;
  }]);

  config = withXcodeProject(config, (cfg) => {
    addNativeModuleSources(cfg.modResults, cfg.modRequest.projectRoot, cfg.modRequest.projectName, 'KeyboardShortcuts');
    return cfg;
  });

  return config;
};

module.exports = withKeyboardShortcuts;
