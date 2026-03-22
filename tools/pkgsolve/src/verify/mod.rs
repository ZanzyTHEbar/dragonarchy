use std::fs;
use std::path::PathBuf;

use anyhow::{Context, Result};

use crate::cli::VerifyArgs;
use crate::debian::{self, DebianContext};
use crate::model::{
    FailureClass, PlanLock, PlanMetadata, ResolutionStatus, TraceLevel, TraceReport, UnsatEntry,
    UnsatReport,
};

#[derive(Debug, Clone)]
pub struct VerifyOutcome {
    pub plan: PlanLock,
    pub unsat: UnsatReport,
    pub trace: TraceReport,
    pub apt_plan: Vec<String>,
    pub preferences: String,
}

pub fn verify(args: &VerifyArgs) -> Result<VerifyOutcome> {
    let raw = fs::read_to_string(&args.plan)
        .with_context(|| format!("failed to read plan {}", args.plan.display()))?;
    let prior_plan: PlanLock = serde_json::from_str(&raw)
        .with_context(|| format!("failed to parse JSON plan {}", args.plan.display()))?;

    let mut metadata = build_metadata(&prior_plan, args);
    metadata.command = "verify".to_string();
    let mut trace = TraceReport::new(metadata.clone());

    let pins = if let Some(pins_path) = args.pins.as_deref() {
        debian::load_pin_rules(Some(pins_path))?
    } else {
        prior_plan.pins.clone()
    };
    let preferences = debian::render_preferences(&pins);
    let sources_list = args
        .sources_list
        .clone()
        .or_else(|| prior_plan.metadata.sources_list.as_ref().map(PathBuf::from));
    let context = DebianContext::new(
        args.metadata_dir.as_deref(),
        sources_list.as_deref(),
        prior_plan.metadata.snapshot.clone(),
        pins.clone(),
        prior_plan.local_debs.clone(),
    )?;

    let mut unsat_entries = Vec::new();
    for entry in &prior_plan.selected {
        if entry.local_deb.is_some() {
            continue;
        }

        let candidate = context.resolve_candidate(&entry.package, Some(&entry.version))?;
        if candidate.is_none() {
            unsat_entries.push(UnsatEntry {
                goal_id: None,
                requested: format!("{}={}", entry.package, entry.version),
                failure_class: FailureClass::MissingVersion,
                message: format!(
                    "locked package {}={} is not available in the selected Debian universe",
                    entry.package, entry.version
                ),
                searched_candidates: Vec::new(),
                violated_constraints: vec!["locked version unavailable".to_string()],
                dropped_in_best_effort: false,
            });
            trace.push(
                "verify",
                TraceLevel::Error,
                format!(
                    "locked package {}={} is unavailable",
                    entry.package, entry.version
                ),
            );
        }
    }

    let apt_plan = build_verify_apt_plan(&prior_plan);

    if unsat_entries.is_empty() {
        if let Err(error) = context.simulate_install(&apt_plan) {
            unsat_entries.push(UnsatEntry {
                goal_id: None,
                requested: "verify".to_string(),
                failure_class: FailureClass::AptSimulationFailed,
                message: error.to_string(),
                searched_candidates: Vec::new(),
                violated_constraints: vec![error.to_string()],
                dropped_in_best_effort: false,
            });
            trace.push("verify", TraceLevel::Error, error.to_string());
        } else {
            trace.push(
                "verify",
                TraceLevel::Info,
                "APT simulation verified the locked plan",
            );
        }
    }

    let status = if unsat_entries.is_empty() {
        ResolutionStatus::Satisfiable
    } else {
        ResolutionStatus::Unsatisfiable
    };
    let plan = PlanLock {
        metadata: metadata.clone(),
        status,
        goals: prior_plan.goals,
        selected: prior_plan.selected,
        local_debs: prior_plan.local_debs,
        pins,
    };
    let unsat = UnsatReport {
        metadata,
        entries: unsat_entries,
    };

    Ok(VerifyOutcome {
        plan,
        unsat,
        trace,
        apt_plan,
        preferences,
    })
}

fn build_metadata(plan: &PlanLock, args: &VerifyArgs) -> PlanMetadata {
    let mut metadata = PlanMetadata::new(
        "verify",
        plan.metadata.platform.clone(),
        plan.metadata.manager.clone(),
    );
    metadata.best_effort = plan.metadata.best_effort;
    metadata.manifest = plan.metadata.manifest.clone();
    metadata.bundle = plan.metadata.bundle.clone();
    metadata.host = plan.metadata.host.clone();
    metadata.features = plan.metadata.features.clone();
    metadata.snapshot = plan.metadata.snapshot.clone();
    metadata.sources_list = args
        .sources_list
        .as_ref()
        .map(|path| path.display().to_string())
        .or_else(|| plan.metadata.sources_list.clone());
    metadata
}

fn build_verify_apt_plan(plan: &PlanLock) -> Vec<String> {
    let mut apt_plan = plan
        .local_debs
        .iter()
        .map(|entry| entry.path.clone())
        .collect::<Vec<_>>();
    apt_plan.extend(
        plan.selected
            .iter()
            .filter(|entry| entry.local_deb.is_none())
            .map(|entry| format!("{}={}", entry.package, entry.version)),
    );
    apt_plan.sort();
    apt_plan.dedup();
    apt_plan
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{LocalDebSummary, LockEntry};

    #[test]
    fn verify_plan_keeps_local_debs_in_apt_requests() {
        let mut plan = PlanLock {
            metadata: PlanMetadata::new("resolve", "debian", "apt"),
            status: ResolutionStatus::Satisfiable,
            goals: Vec::new(),
            selected: vec![LockEntry {
                package: "fd-find".to_string(),
                version: "9.0".to_string(),
                architecture: None,
                origin: None,
                component: None,
                snapshot: None,
                requested_by: Vec::new(),
                mapped_from: Vec::new(),
                local_deb: None,
            }],
            local_debs: vec![LocalDebSummary {
                path: "/tmp/demo.deb".to_string(),
                sha256: "abc".to_string(),
                package: "demo".to_string(),
                version: "1.0".to_string(),
                architecture: Some("amd64".to_string()),
            }],
            pins: Vec::new(),
        };
        plan.selected.push(LockEntry {
            package: "demo".to_string(),
            version: "1.0".to_string(),
            architecture: Some("amd64".to_string()),
            origin: Some("local-deb".to_string()),
            component: Some("local".to_string()),
            snapshot: None,
            requested_by: Vec::new(),
            mapped_from: Vec::new(),
            local_deb: Some(plan.local_debs[0].clone()),
        });

        let apt_plan = build_verify_apt_plan(&plan);
        assert_eq!(
            apt_plan,
            vec!["/tmp/demo.deb".to_string(), "fd-find=9.0".to_string()]
        );
    }
}
