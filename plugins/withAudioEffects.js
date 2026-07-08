/**
 * Config plugin: AppleVisAudioEffects (Voice Boost + Trim Silence)
 *
 * Copies the AVAudioEngine processing module into the Xcode project
 * during `npx expo prebuild`. No extra Info.plist keys are required —
 * audio session access is already granted by the existing 'audio'
 * UIBackgroundMode.
 */
const { withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const path = require('path');
const fs = require('fs');
const { addNativeModuleSources } = require('./lib/addNativeModuleSources');

const withAudioEffects = (config) => {
  config = withDangerousMod(config, [
    'ios',
    (cfg) => {
      const src  = path.join(cfg.modRequest.projectRoot, 'ios-native', 'AudioEffects');
      const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
      if (!fs.existsSync(dest)) return cfg;
      for (const file of fs.readdirSync(src)) {
        fs.copyFileSync(path.join(src, file), path.join(dest, file));
      }
      return cfg;
    },
  ]);

  config = withXcodeProject(config, (cfg) => {
    addNativeModuleSources(cfg.modResults, cfg.modRequest.projectRoot, cfg.modRequest.projectName, 'AudioEffects');
    return cfg;
  });

  return config;
};

module.exports = withAudioEffects;
