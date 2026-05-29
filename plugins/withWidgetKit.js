/**
 * Config plugin: WidgetKit
 *
 * - Adds the App Group entitlement (shared between main app and widget extension)
 * - After `npx expo prebuild`, open ios/AppleVis.xcworkspace in Xcode and:
 *   1. File > New > Target > Widget Extension
 *   2. Name it "AppleVisWidget"
 *   3. Copy ios-native/Widget/ files into the new target
 *   4. Set the App Group to group.com.applevis.app in both the main target and widget target
 */
const { withEntitlementsPlist } = require('@expo/config-plugins');

const withWidgetKit = (config) => {
  config = withEntitlementsPlist(config, (cfg) => {
    const appId = cfg.ios?.bundleIdentifier ?? 'com.applevis.app';
    const groups = cfg.modResults['com.apple.security.application-groups'] ?? [];
    const group = `group.${appId}`;
    if (!groups.includes(group)) {
      cfg.modResults['com.apple.security.application-groups'] = [...groups, group];
    }
    return cfg;
  });
  return config;
};

module.exports = withWidgetKit;
