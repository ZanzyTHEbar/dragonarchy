use std::collections::{BTreeSet, HashMap};
use std::fs;
use std::path::Path;

use anyhow::{Context, Result};
use serde::Deserialize;

use crate::cli::MapArgs;
use crate::debian::DebianContext;
use crate::model::{
    FailureClass, Goal, PlanMetadata, RequestArtifact, TraceLevel, TraceReport, UnsatEntry,
    UnsatReport,
};

#[derive(Debug, Clone)]
pub struct MapOutcome {
    pub requests: RequestArtifact,
    pub unsat: UnsatReport,
    pub trace: TraceReport,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct MappingOverrideFile {
    #[serde(default)]
    exact: HashMap<String, MappingTarget>,
    #[serde(default)]
    unsupported: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
struct MappingTarget {
    package: String,
    #[serde(default = "default_manager")]
    manager: String,
}

fn default_manager() -> String {
    "apt".to_string()
}

pub fn map_arch_packages(args: &MapArgs) -> Result<MapOutcome> {
    let metadata = PlanMetadata::new("map", "debian", "apt");
    let mut trace = TraceReport::new(metadata.clone());
    let overrides = load_overrides(args.mapping_file.as_deref())?;
    let arch_packages = load_arch_packages(&args.arch_input)?;
    let universe = DebianContext::new(
        args.metadata_dir.as_deref(),
        None,
        None,
        Vec::new(),
        Vec::new(),
    )?;

    let mut goals = Vec::new();
    let mut unsat_entries = Vec::new();
    let mut seen = BTreeSet::new();

    for package in arch_packages {
        match map_single_package(&package, &overrides, &universe) {
            MappingDecision::Mapped {
                package: debian_package,
                manager,
                strategy,
            } => {
                let goal = Goal {
                    id: format!("map:{package}"),
                    package: debian_package.clone(),
                    version: None,
                    manager: Some(manager),
                    group: None,
                    source: format!("arch_input:{}", args.arch_input.display()),
                    strict: !args.best_effort,
                    relaxable: args.best_effort,
                    mapped_from: Some(package.clone()),
                };
                if seen.insert(goal.request_key()) {
                    goals.push(goal);
                }
                trace.push(
                    "map",
                    TraceLevel::Info,
                    format!("{package} -> {debian_package} via {strategy}"),
                );
            }
            MappingDecision::Unsupported(message) => {
                trace.push("map", TraceLevel::Warning, message.clone());
                unsat_entries.push(UnsatEntry {
                    goal_id: None,
                    requested: package,
                    failure_class: FailureClass::UnsupportedMapping,
                    message,
                    searched_candidates: Vec::new(),
                    violated_constraints: Vec::new(),
                    dropped_in_best_effort: args.best_effort,
                });
            }
        }
    }

    goals.sort_by(|left, right| left.package.cmp(&right.package));
    let requests = RequestArtifact {
        metadata: metadata.clone(),
        goals,
    };
    let unsat = UnsatReport {
        metadata,
        entries: unsat_entries,
    };

    Ok(MapOutcome {
        requests,
        unsat,
        trace,
    })
}

enum MappingDecision {
    Mapped {
        package: String,
        manager: String,
        strategy: &'static str,
    },
    Unsupported(String),
}

fn map_single_package(
    arch_package: &str,
    overrides: &MappingOverrideFile,
    universe: &DebianContext,
) -> MappingDecision {
    if overrides
        .unsupported
        .iter()
        .any(|item| item == arch_package)
    {
        return MappingDecision::Unsupported(format!(
            "{arch_package} is explicitly marked unsupported in the mapping override file"
        ));
    }

    if let Some(target) = overrides.exact.get(arch_package) {
        return MappingDecision::Mapped {
            package: target.package.clone(),
            manager: target.manager.clone(),
            strategy: "override",
        };
    }

    if let Some((package, manager)) = builtin_mapping(arch_package) {
        return MappingDecision::Mapped {
            package: package.to_string(),
            manager: manager.to_string(),
            strategy: "builtin",
        };
    }

    if arch_package.ends_with("-git")
        || arch_package.ends_with("-bin")
        || arch_package.ends_with("-appimage")
    {
        return MappingDecision::Unsupported(format!(
            "{arch_package} looks like an AUR-specific package and needs a manual Debian mapping"
        ));
    }

    if let Some(stripped) = arch_package.strip_prefix("ttf-") {
        let candidate = format!("fonts-{stripped}");
        return MappingDecision::Mapped {
            package: candidate,
            manager: "apt".to_string(),
            strategy: "font-family",
        };
    }

    if universe
        .lookup_candidates(arch_package)
        .ok()
        .filter(|items| !items.is_empty())
        .is_some()
    {
        return MappingDecision::Mapped {
            package: arch_package.to_string(),
            manager: "apt".to_string(),
            strategy: "exact",
        };
    }

    MappingDecision::Unsupported(format!(
        "no Debian mapping was found for {arch_package}; provide an override or manual package"
    ))
}

fn builtin_mapping(arch_package: &str) -> Option<(&'static str, &'static str)> {
    match arch_package {
        "fd" => Some(("fd-find", "apt")),
        "github-cli" => Some(("gh", "apt")),
        "python-pipx" => Some(("pipx", "apt")),
        "noto-fonts-emoji" => Some(("fonts-noto-color-emoji", "apt")),
        "ttf-jetbrains-mono" => Some(("fonts-jetbrains-mono", "apt")),
        "ttf-font-awesome" => Some(("fonts-font-awesome", "apt")),
        "ttf-liberation" => Some(("fonts-liberation2", "apt")),
        "joplin-desktop" => Some(("joplin-desktop", "script")),
        "localsend" => Some(("localsend", "script")),
        "vivaldi" => Some(("vivaldi", "script")),
        "visual-studio-code-bin" => Some(("visual-studio-code-bin", "script")),
        "visual-studio-code-insiders-bin" => Some(("visual-studio-code-insiders-bin", "script")),
        "gum" => Some(("gum", "script")),
        "lazygit" => Some(("lazygit", "script")),
        "mise" => Some(("mise", "script")),
        _ => None,
    }
}

fn load_arch_packages(path: &Path) -> Result<Vec<String>> {
    let raw = fs::read_to_string(path)
        .with_context(|| format!("failed to read Arch input {}", path.display()))?;
    let mut packages = Vec::new();

    for line in raw.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        let package = trimmed
            .split_whitespace()
            .next()
            .map(ToString::to_string)
            .unwrap_or_else(|| trimmed.to_string());
        packages.push(package);
    }

    Ok(packages)
}

fn load_overrides(path: Option<&Path>) -> Result<MappingOverrideFile> {
    let Some(path) = path else {
        return Ok(MappingOverrideFile::default());
    };

    let raw = fs::read_to_string(path)
        .with_context(|| format!("failed to read mapping override file {}", path.display()))?;
    match path.extension().and_then(|value| value.to_str()) {
        Some("json") => serde_json::from_str(&raw)
            .with_context(|| format!("failed to parse JSON mapping file {}", path.display())),
        _ => toml::from_str(&raw)
            .with_context(|| format!("failed to parse TOML mapping file {}", path.display())),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_arch_input_lines() {
        let content = "fd 1.0\n# comment\nbat\n";
        let temp = tempfile::NamedTempFile::new().unwrap();
        fs::write(temp.path(), content).unwrap();

        let packages = load_arch_packages(temp.path()).unwrap();
        assert_eq!(packages, vec!["fd".to_string(), "bat".to_string()]);
    }

    #[test]
    fn builtin_mapping_covers_fd() {
        assert_eq!(builtin_mapping("fd"), Some(("fd-find", "apt")));
    }
}
