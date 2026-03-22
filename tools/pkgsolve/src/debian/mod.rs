use std::ffi::OsStr;
use std::fs;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{anyhow, bail, Context, Result};
use flate2::read::GzDecoder;
use indexmap::IndexMap;
use serde::de::DeserializeOwned;
use sha2::{Digest, Sha256};
use tempfile::NamedTempFile;
use walkdir::WalkDir;

use crate::model::{
    FailureClass, Goal, LocalDebManifest, LocalDebSpec, LocalDebSummary, PackageAtom, PinManifest,
    PinRule, TraceLevel, TraceReport, UnsatEntry,
};

#[derive(Debug, Clone)]
pub struct AptSimulation {
    pub stdout: String,
    pub stderr: String,
    pub installed: Vec<PackageAtom>,
    pub command: Vec<String>,
}

#[derive(Debug, Clone, Default)]
pub struct DebianContext {
    metadata: Option<IndexMap<String, Vec<PackageAtom>>>,
    sources_list: Option<PathBuf>,
    snapshot: Option<String>,
    pins: Vec<PinRule>,
    pub local_debs: Vec<LocalDebSummary>,
}

impl DebianContext {
    pub fn new(
        metadata_dir: Option<&Path>,
        sources_list: Option<&Path>,
        snapshot: Option<String>,
        pins: Vec<PinRule>,
        local_debs: Vec<LocalDebSummary>,
    ) -> Result<Self> {
        let metadata = match metadata_dir {
            Some(path) => Some(load_metadata_dir(path)?),
            None => None,
        };

        Ok(Self {
            metadata,
            sources_list: sources_list.map(Path::to_path_buf),
            snapshot,
            pins,
            local_debs,
        })
    }

    pub fn lookup_candidates(&self, package: &str) -> Result<Vec<PackageAtom>> {
        let mut candidates = match &self.metadata {
            Some(metadata) => metadata.get(package).cloned().unwrap_or_default(),
            None => query_system_candidates(
                package,
                self.sources_list.as_deref(),
                self.snapshot.as_deref(),
            )?,
        };

        for local_deb in &self.local_debs {
            if local_deb.package == package {
                candidates.push(PackageAtom {
                    package: local_deb.package.clone(),
                    version: local_deb.version.clone(),
                    architecture: local_deb.architecture.clone(),
                    origin: Some("local-deb".to_string()),
                    component: Some("local".to_string()),
                    snapshot: self.snapshot.clone(),
                    provides: Vec::new(),
                    depends: Vec::new(),
                    conflicts: Vec::new(),
                    breaks: Vec::new(),
                    recommends: Vec::new(),
                    local_deb: Some(local_deb.clone()),
                });
            }
        }

        candidates.sort_by(|left, right| left.version.cmp(&right.version));
        candidates
            .dedup_by(|left, right| left.package == right.package && left.version == right.version);
        Ok(candidates)
    }

    pub fn resolve_candidate(
        &self,
        package: &str,
        version: Option<&str>,
    ) -> Result<Option<PackageAtom>> {
        let candidates = self.lookup_candidates(package)?;
        if let Some(version) = version {
            Ok(candidates
                .into_iter()
                .find(|candidate| candidate.version == version))
        } else {
            Ok(candidates.into_iter().next())
        }
    }

    pub fn check_goal(
        &self,
        goal: &Goal,
        locked_version: Option<&str>,
    ) -> Result<Vec<PackageAtom>> {
        let version = locked_version.or(goal.version.as_deref());
        let candidates = self.lookup_candidates(&goal.package)?;

        if let Some(version) = version {
            Ok(candidates
                .into_iter()
                .filter(|candidate| candidate.version == version)
                .collect())
        } else {
            Ok(candidates)
        }
    }

    pub fn simulate_install(&self, requests: &[String]) -> Result<AptSimulation> {
        let mut preferences_file = None;
        let mut command = Command::new("apt-get");

        command.arg("-s");
        command.arg("-o").arg("Debug::NoLocking=1");
        command.arg("--allow-downgrades");

        if !self.pins.is_empty() {
            let mut temp_file =
                NamedTempFile::new().context("failed to create temporary preferences file")?;
            temp_file
                .write_all(render_preferences(&self.pins).as_bytes())
                .context("failed to write temporary preferences file")?;

            command
                .arg("-o")
                .arg(format!(
                    "Dir::Etc::preferences={}",
                    temp_file.path().display()
                ))
                .arg("-o")
                .arg("Dir::Etc::preferencesparts=-");
            preferences_file = Some(temp_file);
        }

        if let Some(sources_list) = &self.sources_list {
            command
                .arg("-o")
                .arg(format!("Dir::Etc::sourcelist={}", sources_list.display()))
                .arg("-o")
                .arg("Dir::Etc::sourceparts=-");
        }

        command.arg("install");
        for request in requests {
            command.arg(request);
        }
        for local_deb in &self.local_debs {
            command.arg(&local_deb.path);
        }

        let command_preview = command
            .get_args()
            .map(|argument| argument.to_string_lossy().to_string())
            .collect::<Vec<_>>();

        let output = command
            .output()
            .context("failed to run apt-get simulation; ensure apt-get is available")?;

        drop(preferences_file);

        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        if !output.status.success() {
            bail!("apt-get simulation failed\nstdout:\n{stdout}\nstderr:\n{stderr}");
        }

        let installed = parse_apt_simulation(&stdout, self.snapshot.as_deref())?;

        Ok(AptSimulation {
            stdout,
            stderr,
            installed,
            command: command_preview,
        })
    }
}

pub fn load_pin_rules(path: Option<&Path>) -> Result<Vec<PinRule>> {
    match path {
        Some(path) => Ok(read_structured_file::<PinManifest>(path)?.pins),
        None => Ok(Vec::new()),
    }
}

pub fn load_local_deb_specs(path: Option<&Path>) -> Result<Vec<LocalDebSpec>> {
    match path {
        Some(path) => Ok(read_structured_file::<LocalDebManifest>(path)?.packages),
        None => Ok(Vec::new()),
    }
}

pub fn prepare_local_debs(specs: &[LocalDebSpec]) -> Result<Vec<LocalDebSummary>> {
    let mut output = Vec::new();

    for spec in specs {
        let path = Path::new(&spec.path);
        if !path.exists() {
            bail!("local deb not found: {}", path.display());
        }

        let checksum = sha256_file(path)?;
        if let Some(expected) = &spec.sha256 {
            if &checksum != expected {
                bail!(
                    "sha256 mismatch for {}: expected {}, got {}",
                    path.display(),
                    expected,
                    checksum
                );
            }
        }

        let metadata = extract_local_deb_metadata(path)?;
        output.push(LocalDebSummary {
            path: path.display().to_string(),
            sha256: checksum,
            package: metadata.get("Package").cloned().unwrap_or_else(|| {
                path.file_stem()
                    .unwrap_or_else(|| OsStr::new("local"))
                    .to_string_lossy()
                    .to_string()
            }),
            version: metadata
                .get("Version")
                .cloned()
                .unwrap_or_else(|| "unknown".to_string()),
            architecture: metadata.get("Architecture").cloned(),
        });
    }

    Ok(output)
}

pub fn push_local_deb_unsat(
    trace: &mut TraceReport,
    error: &anyhow::Error,
    entries: &mut Vec<UnsatEntry>,
    best_effort: bool,
) {
    trace.push("local_debs", TraceLevel::Error, error.to_string());
    entries.push(UnsatEntry {
        goal_id: None,
        requested: "local_deb_manifest".to_string(),
        failure_class: FailureClass::MissingLocalDeb,
        message: error.to_string(),
        searched_candidates: Vec::new(),
        violated_constraints: Vec::new(),
        dropped_in_best_effort: best_effort,
    });
}

pub fn render_preferences(pins: &[PinRule]) -> String {
    let mut blocks = Vec::new();

    for pin in pins {
        let pin_expression = if let Some(pin_value) = &pin.pin {
            pin_value.clone()
        } else if let Some(version) = &pin.version {
            format!("version {version}")
        } else if let Some(origin) = &pin.origin {
            format!("origin {origin}")
        } else if let Some(release) = &pin.release {
            format!("release {release}")
        } else {
            "*".to_string()
        };

        blocks.push(format!(
            "Package: {}\nPin: {}\nPin-Priority: {}",
            pin.package, pin_expression, pin.priority
        ));
    }

    blocks.join("\n\n")
}

fn read_structured_file<T: DeserializeOwned>(path: &Path) -> Result<T> {
    let raw = fs::read_to_string(path)
        .with_context(|| format!("failed to read structured input file {}", path.display()))?;

    match path.extension().and_then(OsStr::to_str) {
        Some("json") => serde_json::from_str(&raw)
            .with_context(|| format!("failed to parse JSON file {}", path.display())),
        _ => toml::from_str(&raw)
            .with_context(|| format!("failed to parse TOML file {}", path.display())),
    }
}

fn load_metadata_dir(path: &Path) -> Result<IndexMap<String, Vec<PackageAtom>>> {
    let mut packages: IndexMap<String, Vec<PackageAtom>> = IndexMap::new();

    for entry in WalkDir::new(path).into_iter().filter_map(Result::ok) {
        if !entry.file_type().is_file() {
            continue;
        }

        let file_name = entry.file_name().to_string_lossy();
        if file_name != "Packages" && file_name != "Packages.gz" {
            continue;
        }

        for atom in parse_packages_index(entry.path())? {
            packages.entry(atom.package.clone()).or_default().push(atom);
        }
    }

    Ok(packages)
}

fn parse_packages_index(path: &Path) -> Result<Vec<PackageAtom>> {
    let mut raw = Vec::new();
    if path.extension().and_then(OsStr::to_str) == Some("gz") {
        GzDecoder::new(fs::File::open(path)?)
            .read_to_end(&mut raw)
            .with_context(|| format!("failed to decompress {}", path.display()))?;
    } else {
        fs::File::open(path)?
            .read_to_end(&mut raw)
            .with_context(|| format!("failed to read {}", path.display()))?;
    }

    let content = String::from_utf8_lossy(&raw);
    let component = derive_component_from_path(path);
    let paragraphs = parse_control_paragraphs(&content);
    let mut atoms = Vec::new();

    for paragraph in paragraphs {
        let Some(package) = paragraph.get("Package").cloned() else {
            continue;
        };
        let Some(version) = paragraph.get("Version").cloned() else {
            continue;
        };

        atoms.push(PackageAtom {
            package,
            version,
            architecture: paragraph.get("Architecture").cloned(),
            origin: paragraph.get("Origin").cloned(),
            component: component.clone(),
            snapshot: None,
            provides: split_relation_list(paragraph.get("Provides")),
            depends: split_relation_list(paragraph.get("Depends")),
            conflicts: split_relation_list(paragraph.get("Conflicts")),
            breaks: split_relation_list(paragraph.get("Breaks")),
            recommends: split_relation_list(paragraph.get("Recommends")),
            local_deb: None,
        });
    }

    Ok(atoms)
}

fn query_system_candidates(
    package: &str,
    sources_list: Option<&Path>,
    snapshot: Option<&str>,
) -> Result<Vec<PackageAtom>> {
    let Some(madison) = run_apt_cache(["madison", package], sources_list)? else {
        return Ok(Vec::new());
    };
    let mut candidates = Vec::new();

    for line in madison.lines() {
        let columns = line
            .split('|')
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .collect::<Vec<_>>();
        if columns.len() < 2 {
            continue;
        }

        let version = columns[1].to_string();
        let origin = columns.get(2).map(|value| (*value).to_string());
        let detailed =
            query_show_candidate(package, &version, sources_list).unwrap_or_else(|_| PackageAtom {
                package: package.to_string(),
                version: version.clone(),
                architecture: None,
                origin: origin.clone(),
                component: None,
                snapshot: snapshot.map(str::to_string),
                provides: Vec::new(),
                depends: Vec::new(),
                conflicts: Vec::new(),
                breaks: Vec::new(),
                recommends: Vec::new(),
                local_deb: None,
            });
        candidates.push(detailed);
    }

    if candidates.is_empty() {
        let Some(show) = run_apt_cache(["show", package], sources_list)? else {
            return Ok(Vec::new());
        };
        for paragraph in parse_control_paragraphs(&show) {
            let Some(version) = paragraph.get("Version").cloned() else {
                continue;
            };

            candidates.push(PackageAtom {
                package: package.to_string(),
                version,
                architecture: paragraph.get("Architecture").cloned(),
                origin: paragraph.get("Origin").cloned(),
                component: None,
                snapshot: snapshot.map(str::to_string),
                provides: split_relation_list(paragraph.get("Provides")),
                depends: split_relation_list(paragraph.get("Depends")),
                conflicts: split_relation_list(paragraph.get("Conflicts")),
                breaks: split_relation_list(paragraph.get("Breaks")),
                recommends: split_relation_list(paragraph.get("Recommends")),
                local_deb: None,
            });
        }
    }

    Ok(candidates)
}

fn query_show_candidate(
    package: &str,
    version: &str,
    sources_list: Option<&Path>,
) -> Result<PackageAtom> {
    let selector = format!("{package}={version}");
    let Some(show) = run_apt_cache(["show", selector.as_str()], sources_list)? else {
        bail!("package {package} version {version} not found in apt-cache show output");
    };
    let paragraphs = parse_control_paragraphs(&show);
    let paragraph = paragraphs
        .into_iter()
        .find(|entry| entry.get("Version").map(String::as_str) == Some(version))
        .ok_or_else(|| {
            anyhow!("package {package} version {version} not found in apt-cache show output")
        })?;

    Ok(PackageAtom {
        package: package.to_string(),
        version: version.to_string(),
        architecture: paragraph.get("Architecture").cloned(),
        origin: paragraph.get("Origin").cloned(),
        component: None,
        snapshot: None,
        provides: split_relation_list(paragraph.get("Provides")),
        depends: split_relation_list(paragraph.get("Depends")),
        conflicts: split_relation_list(paragraph.get("Conflicts")),
        breaks: split_relation_list(paragraph.get("Breaks")),
        recommends: split_relation_list(paragraph.get("Recommends")),
        local_deb: None,
    })
}

fn run_apt_cache<I, S>(args: I, sources_list: Option<&Path>) -> Result<Option<String>>
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let mut command = Command::new("apt-cache");
    if let Some(sources_list) = sources_list {
        command
            .arg("-o")
            .arg(format!("Dir::Etc::sourcelist={}", sources_list.display()))
            .arg("-o")
            .arg("Dir::Etc::sourceparts=-");
    }
    command.args(args);

    let output = command
        .output()
        .context("failed to run apt-cache; ensure apt-cache is available")?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if apt_cache_reports_no_packages(stderr.as_ref()) {
            return Ok(None);
        }
        bail!("apt-cache failed: {}", stderr);
    }
    Ok(Some(String::from_utf8_lossy(&output.stdout).to_string()))
}

fn apt_cache_reports_no_packages(stderr: &str) -> bool {
    let trimmed = stderr.trim();
    trimmed == "E: No packages found" || trimmed.ends_with(": No packages found")
}

fn extract_local_deb_metadata(path: &Path) -> Result<IndexMap<String, String>> {
    let output = Command::new("dpkg-deb")
        .arg("-f")
        .arg(path)
        .output()
        .context("failed to run dpkg-deb; ensure dpkg-deb is available")?;

    if !output.status.success() {
        bail!(
            "dpkg-deb failed for {}: {}",
            path.display(),
            String::from_utf8_lossy(&output.stderr)
        );
    }

    let content = String::from_utf8_lossy(&output.stdout);
    let mut paragraphs = parse_control_paragraphs(&content);
    Ok(paragraphs.pop().unwrap_or_default())
}

fn parse_control_paragraphs(content: &str) -> Vec<IndexMap<String, String>> {
    let mut paragraphs = Vec::new();
    let mut current = IndexMap::new();
    let mut last_key = None::<String>;

    for raw_line in content.lines() {
        let line = raw_line.trim_end();
        if line.is_empty() {
            if !current.is_empty() {
                paragraphs.push(current);
                current = IndexMap::new();
                last_key = None;
            }
            continue;
        }

        if line.starts_with(' ') || line.starts_with('\t') {
            if let Some(key) = &last_key {
                let entry = current.entry(key.clone()).or_insert_with(String::new);
                if !entry.is_empty() {
                    entry.push('\n');
                }
                entry.push_str(line.trim());
            }
            continue;
        }

        if let Some((key, value)) = line.split_once(':') {
            let key = key.trim().to_string();
            current.insert(key.clone(), value.trim().to_string());
            last_key = Some(key);
        }
    }

    if !current.is_empty() {
        paragraphs.push(current);
    }

    paragraphs
}

fn split_relation_list(value: Option<&String>) -> Vec<String> {
    value
        .map(|raw| {
            raw.split(',')
                .map(str::trim)
                .filter(|entry| !entry.is_empty())
                .map(ToString::to_string)
                .collect()
        })
        .unwrap_or_default()
}

fn derive_component_from_path(path: &Path) -> Option<String> {
    let path_string = path.display().to_string();
    for marker in ["/main/", "/contrib/", "/non-free/"] {
        if let Some((_, tail)) = path_string.split_once(marker) {
            let component = marker.trim_matches('/').to_string();
            if !tail.is_empty() {
                return Some(component);
            }
        }
    }
    None
}

fn parse_apt_simulation(stdout: &str, snapshot: Option<&str>) -> Result<Vec<PackageAtom>> {
    let mut output = Vec::new();

    for line in stdout.lines() {
        let trimmed = line.trim();
        if !trimmed.starts_with("Inst ") {
            continue;
        }

        let body = trimmed.trim_start_matches("Inst ").trim();
        let (package, rest) = body
            .split_once(' ')
            .ok_or_else(|| anyhow!("unexpected apt simulation line: {trimmed}"))?;

        let version_segment = rest
            .split('(')
            .nth(1)
            .and_then(|value| value.split(')').next())
            .unwrap_or_default();
        let mut version_parts = version_segment.split_whitespace();
        let version = version_parts.next().unwrap_or("unknown").to_string();
        let origin = if version_segment.is_empty() {
            None
        } else {
            let remaining = version_parts.collect::<Vec<_>>().join(" ");
            if remaining.is_empty() {
                None
            } else {
                Some(remaining)
            }
        };

        output.push(PackageAtom {
            package: package.to_string(),
            version,
            architecture: None,
            origin,
            component: None,
            snapshot: snapshot.map(str::to_string),
            provides: Vec::new(),
            depends: Vec::new(),
            conflicts: Vec::new(),
            breaks: Vec::new(),
            recommends: Vec::new(),
            local_deb: None,
        });
    }

    Ok(output)
}

fn sha256_file(path: &Path) -> Result<String> {
    let mut file = fs::File::open(path)
        .with_context(|| format!("failed to open {} for sha256", path.display()))?;
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 8192];

    loop {
        let read = file.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_control_paragraphs() {
        let content = "\
Package: demo\n\
Version: 1.0\n\
Depends: libc6, zlib1g\n\
\n\
Package: second\n\
Version: 2.0\n";
        let paragraphs = parse_control_paragraphs(content);
        assert_eq!(paragraphs.len(), 2);
        assert_eq!(
            paragraphs[0].get("Package").map(String::as_str),
            Some("demo")
        );
        assert_eq!(
            paragraphs[1].get("Version").map(String::as_str),
            Some("2.0")
        );
    }

    #[test]
    fn renders_preferences_blocks() {
        let rendered = render_preferences(&[PinRule {
            package: "fd-find".to_string(),
            pin: None,
            version: Some("9.0".to_string()),
            origin: None,
            release: None,
            priority: 1001,
        }]);

        assert!(rendered.contains("Package: fd-find"));
        assert!(rendered.contains("Pin: version 9.0"));
        assert!(rendered.contains("Pin-Priority: 1001"));
    }

    #[test]
    fn detects_missing_package_errors_from_apt_cache() {
        assert!(apt_cache_reports_no_packages("E: No packages found\n"));
        assert!(!apt_cache_reports_no_packages(
            "E: The package cache file is corrupted"
        ));
    }
}
