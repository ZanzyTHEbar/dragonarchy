use chrono::{SecondsFormat, Utc};
use indexmap::IndexMap;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ResolutionStatus {
    Satisfiable,
    PartiallySatisfiable,
    Unsatisfiable,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FailureClass {
    MissingPackage,
    MissingVersion,
    MissingLocalDeb,
    ChecksumMismatch,
    AptSimulationFailed,
    PinViolation,
    SnapshotViolation,
    UnsupportedMapping,
    MetadataUnavailable,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TraceLevel {
    Info,
    Warning,
    Error,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlanMetadata {
    pub tool: String,
    pub generated_at: String,
    pub command: String,
    pub platform: String,
    pub manager: String,
    pub best_effort: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub manifest: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bundle: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub host: Option<String>,
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub features: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub snapshot: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sources_list: Option<String>,
}

impl PlanMetadata {
    pub fn new(command: &str, platform: impl Into<String>, manager: impl Into<String>) -> Self {
        Self {
            tool: "pkgsolve".to_string(),
            generated_at: now_timestamp(),
            command: command.to_string(),
            platform: platform.into(),
            manager: manager.into(),
            best_effort: false,
            manifest: None,
            bundle: None,
            host: None,
            features: Vec::new(),
            snapshot: None,
            sources_list: None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Goal {
    pub id: String,
    pub package: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub manager: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub group: Option<String>,
    pub source: String,
    pub strict: bool,
    pub relaxable: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mapped_from: Option<String>,
}

impl Goal {
    pub fn request_key(&self) -> String {
        match &self.version {
            Some(version) => format!("{}={version}", self.package),
            None => self.package.clone(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PackageAtom {
    pub package: String,
    pub version: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub architecture: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub origin: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub component: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub snapshot: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub provides: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub depends: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub conflicts: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub breaks: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub recommends: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub local_deb: Option<LocalDebSummary>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LockEntry {
    pub package: String,
    pub version: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub architecture: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub origin: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub component: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub snapshot: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub requested_by: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub mapped_from: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub local_deb: Option<LocalDebSummary>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PinRule {
    #[serde(default = "default_pin_package")]
    pub package: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pin: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub origin: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub release: Option<String>,
    pub priority: i32,
}

fn default_pin_package() -> String {
    "*".to_string()
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalDebSpec {
    pub path: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sha256: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalDebSummary {
    pub path: String,
    pub sha256: String,
    pub package: String,
    pub version: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub architecture: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlanLock {
    pub metadata: PlanMetadata,
    pub status: ResolutionStatus,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub goals: Vec<Goal>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub selected: Vec<LockEntry>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub local_debs: Vec<LocalDebSummary>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub pins: Vec<PinRule>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RequestArtifact {
    pub metadata: PlanMetadata,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub goals: Vec<Goal>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UnsatEntry {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub goal_id: Option<String>,
    pub requested: String,
    pub failure_class: FailureClass,
    pub message: String,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub searched_candidates: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub violated_constraints: Vec<String>,
    pub dropped_in_best_effort: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UnsatReport {
    pub metadata: PlanMetadata,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub entries: Vec<UnsatEntry>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TraceEvent {
    pub phase: String,
    pub level: TraceLevel,
    pub message: String,
    #[serde(default, skip_serializing_if = "IndexMap::is_empty")]
    pub details: IndexMap<String, serde_json::Value>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TraceReport {
    pub metadata: PlanMetadata,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub events: Vec<TraceEvent>,
}

impl TraceReport {
    pub fn new(metadata: PlanMetadata) -> Self {
        Self {
            metadata,
            events: Vec::new(),
        }
    }

    pub fn push(
        &mut self,
        phase: impl Into<String>,
        level: TraceLevel,
        message: impl Into<String>,
    ) {
        self.events.push(TraceEvent {
            phase: phase.into(),
            level,
            message: message.into(),
            details: IndexMap::new(),
        });
    }

    pub fn push_detail(
        &mut self,
        phase: impl Into<String>,
        level: TraceLevel,
        message: impl Into<String>,
        details: IndexMap<String, serde_json::Value>,
    ) {
        self.events.push(TraceEvent {
            phase: phase.into(),
            level,
            message: message.into(),
            details,
        });
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct DirectRequestFile {
    #[serde(default)]
    pub goals: Vec<Goal>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalDebManifest {
    #[serde(default)]
    pub packages: Vec<LocalDebSpec>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct PinManifest {
    #[serde(default)]
    pub pins: Vec<PinRule>,
}

pub fn now_timestamp() -> String {
    Utc::now().to_rfc3339_opts(SecondsFormat::Secs, true)
}
