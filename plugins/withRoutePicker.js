/**
 * Config plugin: AirPlay / Audio Route Picker
 *
 * Copies the AppleVisRoutePicker native module into the main app target
 * during prebuild, enabling programmatic presentation of the system
 * AirPlay / Bluetooth audio route picker sheet.
 */
const { withDangerousMod } = require('@expo/config-plugins');
const path = require('path');
const fs   = require('fs');

const withRoutePicker = (config) => {
  config = withDangerousMod(config, ['ios', (cfg) => {
    const src  = path.join(cfg.modRequest.projectRoot, 'ios-native', 'RoutePicker');
    const dest = path.join(cfg.modRequest.platformProjectRoot, cfg.modRequest.projectName);
    if (fs.existsSync(src)) {
      fs.readdirSync(src).forEach((file) => {
        fs.copyFileSync(path.join(src, file), path.join(dest, file));
      });
    }
    return cfg;
  }]);

  return config;
};

module.exports = withRoutePicker;
