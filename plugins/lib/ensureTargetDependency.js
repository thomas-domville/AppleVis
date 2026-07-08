/**
 * xcodeProject.addTargetDependency() silently no-ops if the project has
 * never had a target dependency before — it guards its writes on the
 * PBXTargetDependency/PBXContainerItemProxy sections already existing
 * (`if (pbxContainerItemProxySection && pbxTargetDependencySection)`), and a
 * freshly cloned single-target React Native template has neither section at
 * all. Ensure both exist (even if empty) before calling addTargetDependency,
 * otherwise the dependency edge is silently dropped with no error.
 */
function ensureTargetDependencySections(xcodeProject) {
  const objects = xcodeProject.hash.project.objects;
  if (!objects.PBXTargetDependency) objects.PBXTargetDependency = {};
  if (!objects.PBXContainerItemProxy) objects.PBXContainerItemProxy = {};
}

/**
 * Once the sections above exist, addTarget()'s own internal dependency call
 * (which silently no-op'd while they were missing) starts succeeding too —
 * so a later call here for a later target would otherwise double up with
 * addTarget()'s own edge for that same pair. Skip any pair that's already
 * wired (checked via the PBXTargetDependency entries' underlying
 * PBXContainerItemProxy.remoteGlobalIDString) rather than adding it blind.
 */
function addTargetDependency(xcodeProject, target, dependencyTargets) {
  ensureTargetDependencySections(xcodeProject);

  const nativeTargets = xcodeProject.pbxNativeTargetSection();
  const targetDependencies = xcodeProject.hash.project.objects.PBXTargetDependency;
  const itemProxies = xcodeProject.hash.project.objects.PBXContainerItemProxy;
  const existingDeps = nativeTargets[target]?.dependencies ?? [];
  // dependencies[].value is a PBXTargetDependency uuid, which points (via
  // .targetProxy) to a PBXContainerItemProxy uuid, which is what actually
  // carries the dependency's target — two levels of indirection to unwrap.
  const alreadyWired = new Set(
    existingDeps
      .map((d) => targetDependencies[d.value]?.targetProxy)
      .map((proxyUuid) => itemProxies[proxyUuid]?.remoteGlobalIDString)
      .filter(Boolean)
  );

  const toAdd = dependencyTargets.filter((depUuid) => !alreadyWired.has(depUuid));
  if (toAdd.length === 0) return { uuid: target, target: nativeTargets[target] };

  return xcodeProject.addTargetDependency(target, toAdd);
}

module.exports = { ensureTargetDependencySections, addTargetDependency };
