/**
 * Registers every native source file (.swift/.m/.mm) found in ios-native/<dir>
 * as a compiled member of a target's Sources build phase.
 *
 * withDangerousMod only copies files onto disk during prebuild — a file that
 * isn't also registered in the Xcode project's Sources build phase for a
 * target simply never compiles. It's not a build error: NativeModules.<Name>
 * just silently resolves to undefined at runtime.
 */
const fs = require('fs');
const path = require('path');

function addNativeModuleSources(xcodeProject, projectRoot, projectName, nativeDir, opts = {}) {
  const nativeSrc = path.join(projectRoot, 'ios-native', nativeDir);
  if (!fs.existsSync(nativeSrc)) return;

  const target = opts.targetUuid ?? xcodeProject.getFirstTarget().uuid;
  const groupKey = opts.groupKey ?? xcodeProject.getFirstProject().firstProject.mainGroup;
  const exclude = new Set(opts.exclude ?? []);

  fs.readdirSync(nativeSrc).forEach((file) => {
    if (exclude.has(file)) return;
    if (!/\.(swift|m|mm)$/.test(file)) return;
    xcodeProject.addSourceFile(`${projectName}/${file}`, { target }, groupKey);
  });
}

module.exports = { addNativeModuleSources };
