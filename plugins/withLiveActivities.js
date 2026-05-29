/**
 * Config plugin: Live Activities + Dynamic Island
 *
 * Sets the Info.plist keys required by ActivityKit.
 * After `npx expo prebuild`, open ios/AppleVis.xcworkspace in Xcode and:
 *   1. File > New > Target > Widget Extension (check "Include Live Activity")
 *   2. Name it "AppleVisLiveActivity"
 *   3. Copy ios-native/LiveActivity/ files into the new target
 *   4. Add the ActivityKit framework to the main app target
 */
const { withInfoPlist } = require('@expo/config-plugins');

const withLiveActivities = (config) => {
  config = withInfoPlist(config, (cfg) => {
    cfg.modResults.NSSupportsLiveActivities = true;
    cfg.modResults.NSSupportsLiveActivitiesFrequentUpdates = true;
    return cfg;
  });
  return config;
};

module.exports = withLiveActivities;
