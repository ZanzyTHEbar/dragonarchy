use std::collections::{BTreeSet, HashSet};
use std::fs;
use std::path::Path;

use anyhow::{anyhow, bail, Context, Result};
use indexmap::IndexMap;
use serde::Deserialize;

use crate::model::Goal;

#[derive(Debug, Clone, Default, Deserialize)]
struct ManifestFile {
    #[serde(default)]
    platforms: IndexMap<String, IndexMap<String, IndexMap<String, ManifestGroup>>>,
    #[serde(default)]
    bundles: IndexMap<String, ManifestBundle>,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct ManifestGroup {
    #[serde(default)]
    packages: Vec<String>,
    #[serde(default)]
    requires_features: Vec<String>,
    #[serde(default)]
    requires_hosts: Vec<String>,
    #[serde(default)]
    exclude_hosts: Vec<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct ManifestBundle {
    #[serde(default)]
    groups: Vec<String>,
    #[serde(default)]
    extends: Vec<String>,
}

pub fn load_manifest(path: &Path) -> Result<String> {
    fs::read_to_string(path)
        .with_context(|| format!("failed to read manifest at {}", path.display()))
}

pub fn resolve_manifest_goals(
    manifest_path: &Path,
    platform: &str,
    manager: &str,
    bundle: Option<&str>,
    host: Option<&str>,
    features: &[String],
) -> Result<Vec<Goal>> {
    let raw = load_manifest(manifest_path)?;
    let manifest: ManifestFile = toml::from_str(&raw)
        .with_context(|| format!("failed to parse TOML manifest {}", manifest_path.display()))?;

    let managers = manifest
        .platforms
        .get(platform)
        .ok_or_else(|| anyhow!("platform '{platform}' not found in manifest"))?;

    let groups = managers
        .get(manager)
        .ok_or_else(|| anyhow!("manager '{manager}' not found for platform '{platform}'"))?;

    let selected_groups = match bundle {
        Some(bundle_name) => resolve_bundle_groups_from_manifest(&manifest, bundle_name)?,
        None => groups.keys().cloned().collect(),
    };

    let feature_set: HashSet<&str> = features.iter().map(String::as_str).collect();
    let mut output = Vec::new();
    let mut seen = BTreeSet::new();

    for group_name in selected_groups {
        let Some(group) = groups.get(&group_name) else {
            continue;
        };

        if !group_enabled(group, host, &feature_set) {
            continue;
        }

        for (package_name, version) in normalize_group_packages(&group.packages) {
            let goal = Goal {
                id: format!("manifest:{platform}:{manager}:{group_name}:{package_name}"),
                package: package_name.clone(),
                version,
                manager: Some(manager.to_string()),
                group: Some(group_name.clone()),
                source: format!("manifest:{}", manifest_path.display()),
                strict: true,
                relaxable: false,
                mapped_from: None,
            };

            if seen.insert(goal.request_key()) {
                output.push(goal);
            }
        }
    }

    Ok(output)
}

pub fn resolve_bundle_groups(manifest_path: &Path, bundle: &str) -> Result<Vec<String>> {
    let raw = load_manifest(manifest_path)?;
    let manifest: ManifestFile = toml::from_str(&raw)
        .with_context(|| format!("failed to parse TOML manifest {}", manifest_path.display()))?;

    resolve_bundle_groups_from_manifest(&manifest, bundle)
}

fn resolve_bundle_groups_from_manifest(
    manifest: &ManifestFile,
    bundle: &str,
) -> Result<Vec<String>> {
    let mut visited = HashSet::new();
    let mut output = Vec::new();
    let mut seen_groups = HashSet::new();

    walk_bundle(
        manifest,
        bundle,
        &mut visited,
        &mut seen_groups,
        &mut output,
    )?;
    Ok(output)
}

fn walk_bundle(
    manifest: &ManifestFile,
    bundle: &str,
    visited: &mut HashSet<String>,
    seen_groups: &mut HashSet<String>,
    output: &mut Vec<String>,
) -> Result<()> {
    if !visited.insert(bundle.to_string()) {
        return Ok(());
    }

    let Some(bundle_def) = manifest.bundles.get(bundle) else {
        bail!("bundle '{bundle}' not found in manifest");
    };

    for parent in &bundle_def.extends {
        walk_bundle(manifest, parent, visited, seen_groups, output)?;
    }

    for group in &bundle_def.groups {
        if seen_groups.insert(group.clone()) {
            output.push(group.clone());
        }
    }

    Ok(())
}

fn group_enabled(group: &ManifestGroup, host: Option<&str>, features: &HashSet<&str>) -> bool {
    if group
        .requires_features
        .iter()
        .any(|feature| !features.contains(feature.as_str()))
    {
        return false;
    }

    if !group.requires_hosts.is_empty()
        && !group
            .requires_hosts
            .iter()
            .any(|required_host| host == Some(required_host.as_str()))
    {
        return false;
    }

    if group
        .exclude_hosts
        .iter()
        .any(|excluded_host| host == Some(excluded_host.as_str()))
    {
        return false;
    }

    true
}

fn normalize_group_packages(packages: &[String]) -> Vec<(String, Option<String>)> {
    let mut output = Vec::new();

    for package in packages {
        for item in package.split(',') {
            let trimmed = item.trim();
            if trimmed.is_empty() {
                continue;
            }

            let (name, version) = parse_package_request(trimmed);
            output.push((name, version));
        }
    }

    output
}

pub fn parse_package_request(input: &str) -> (String, Option<String>) {
    if let Some((package, version)) = input.split_once('=') {
        (package.trim().to_string(), Some(version.trim().to_string()))
    } else {
        (input.trim().to_string(), None)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_package_request_with_version() {
        let (package, version) = parse_package_request("fd-find=9.0");
        assert_eq!(package, "fd-find");
        assert_eq!(version.as_deref(), Some("9.0"));
    }

    #[test]
    fn normalizes_comma_separated_package_entries() {
        let items = normalize_group_packages(&["parted,e2fsprogs".to_string()]);
        assert_eq!(items.len(), 2);
        assert_eq!(items[0].0, "parted");
        assert_eq!(items[1].0, "e2fsprogs");
    }
}
