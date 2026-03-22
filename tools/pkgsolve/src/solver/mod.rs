use std::collections::{BTreeSet, HashMap};
use std::ffi::OsStr;
use std::fs;
use std::path::Path;

use anyhow::{bail, Context, Result};
use indexmap::IndexMap;

use crate::cli::ResolveArgs;
use crate::debian::{self, AptSimulation, DebianContext};
use crate::manifest;
use crate::model::{
    DirectRequestFile, FailureClass, Goal, LockEntry, PlanLock, PlanMetadata, ResolutionStatus,
    TraceLevel, TraceReport, UnsatEntry, UnsatReport,
};

#[derive(Debug, Clone)]
pub struct ResolveOutcome {
    pub plan: PlanLock,
    pub unsat: UnsatReport,
    pub trace: TraceReport,
    pub apt_plan: Vec<String>,
    pub preferences: String,
}

pub fn resolve(args: &ResolveArgs) -> Result<ResolveOutcome> {
    let metadata = build_metadata(args);
    let mut trace = TraceReport::new(metadata.clone());
    let mut unsat_entries = Vec::new();
    let mut goals = collect_goals(args, &mut trace)?;
    if args.best_effort {
        for goal in &mut goals {
            goal.strict = false;
            goal.relaxable = true;
        }
    }
    goals.sort_by_key(|goal| goal.request_key());

    let pins = debian::load_pin_rules(args.pins.as_deref())?;
    let preferences = debian::render_preferences(&pins);
    let local_deb_specs = debian::load_local_deb_specs(args.local_debs.as_deref())?;
    let local_debs = match debian::prepare_local_debs(&local_deb_specs) {
        Ok(items) => items,
        Err(error) => {
            debian::push_local_deb_unsat(&mut trace, &error, &mut unsat_entries, args.best_effort);
            Vec::new()
        }
    };

    let lock_versions = load_lock_versions(args.lockfile.as_deref())?;
    let context = DebianContext::new(
        args.metadata_dir.as_deref(),
        args.sources_list.as_deref(),
        args.snapshot.clone(),
        pins.clone(),
        local_debs.clone(),
    )?;

    let mut available_goals = Vec::new();
    for goal in &goals {
        let locked_version = lock_versions.get(&goal.package).map(String::as_str);
        let candidates = context.check_goal(goal, locked_version)?;
        if candidates.is_empty() {
            let requested = locked_version
                .map(|version| format!("{}={version}", goal.package))
                .unwrap_or_else(|| goal.request_key());

            let failure_class = if locked_version.is_some() || goal.version.is_some() {
                FailureClass::MissingVersion
            } else {
                FailureClass::MissingPackage
            };

            unsat_entries.push(UnsatEntry {
                goal_id: Some(goal.id.clone()),
                requested,
                failure_class,
                message: format!("no Debian candidates found for {}", goal.package),
                searched_candidates: Vec::new(),
                violated_constraints: Vec::new(),
                dropped_in_best_effort: args.best_effort && goal.relaxable,
            });
            trace.push(
                "availability",
                TraceLevel::Warning,
                format!("goal {} has no candidates", goal.package),
            );
            continue;
        }

        trace.push(
            "availability",
            TraceLevel::Info,
            format!(
                "goal {} has {} candidate(s)",
                goal.package,
                candidates.len()
            ),
        );
        available_goals.push(goal.clone());
    }

    let selection = if args.best_effort {
        select_best_effort(&context, &available_goals, &lock_versions, &mut trace)?
    } else {
        select_strict(&context, &available_goals, &lock_versions, &mut trace)?
    };

    let mut selected_goals = selection.goals;
    let mut simulation = selection.simulation;
    if !selection.rejected.is_empty() {
        unsat_entries.extend(selection.rejected);
    }

    if !args.best_effort {
        let required_missing = unsat_entries
            .iter()
            .any(|entry| !entry.dropped_in_best_effort);
        if required_missing && selected_goals.is_empty() {
            trace.push(
                "resolution",
                TraceLevel::Error,
                "strict resolution failed before APT planning",
            );
        }
    }

    let status = match (
        selected_goals.is_empty(),
        unsat_entries.is_empty(),
        args.best_effort,
    ) {
        (false, true, _) => ResolutionStatus::Satisfiable,
        (false, false, true) => ResolutionStatus::PartiallySatisfiable,
        (_, false, _) => ResolutionStatus::Unsatisfiable,
        _ => ResolutionStatus::Unsatisfiable,
    };

    if status == ResolutionStatus::Unsatisfiable && !args.best_effort {
        simulation = empty_simulation();
        selected_goals.clear();
    }

    let lock_entries = build_lock_entries(
        &context,
        &selected_goals,
        &lock_versions,
        &simulation,
        args.snapshot.as_deref(),
    )?;
    let apt_plan = build_apt_plan(&lock_entries, &context.local_debs);

    let plan = PlanLock {
        metadata: metadata.clone(),
        status,
        goals,
        selected: lock_entries,
        local_debs: context.local_debs.clone(),
        pins,
    };
    let unsat = UnsatReport {
        metadata: metadata.clone(),
        entries: unsat_entries,
    };

    Ok(ResolveOutcome {
        plan,
        unsat,
        trace,
        apt_plan,
        preferences,
    })
}

#[derive(Debug)]
struct GoalSelection {
    goals: Vec<Goal>,
    rejected: Vec<UnsatEntry>,
    simulation: AptSimulation,
}

fn select_strict(
    context: &DebianContext,
    goals: &[Goal],
    lock_versions: &HashMap<String, String>,
    trace: &mut TraceReport,
) -> Result<GoalSelection> {
    if goals.is_empty() {
        return Ok(GoalSelection {
            goals: Vec::new(),
            rejected: Vec::new(),
            simulation: empty_simulation(),
        });
    }

    let requests = requests_for_goals(goals, lock_versions);
    match simulate_goal_set(context, &requests) {
        Ok(simulation) => Ok(GoalSelection {
            goals: goals.to_vec(),
            rejected: Vec::new(),
            simulation,
        }),
        Err(error) => {
            trace.push("apt", TraceLevel::Error, error.to_string());
            let rejected = goals
                .iter()
                .map(|goal| UnsatEntry {
                    goal_id: Some(goal.id.clone()),
                    requested: goal.request_key(),
                    failure_class: FailureClass::AptSimulationFailed,
                    message: error.to_string(),
                    searched_candidates: Vec::new(),
                    violated_constraints: vec![error.to_string()],
                    dropped_in_best_effort: false,
                })
                .collect();

            Ok(GoalSelection {
                goals: Vec::new(),
                rejected,
                simulation: empty_simulation(),
            })
        }
    }
}

fn select_best_effort(
    context: &DebianContext,
    goals: &[Goal],
    lock_versions: &HashMap<String, String>,
    trace: &mut TraceReport,
) -> Result<GoalSelection> {
    let required_goals = goals
        .iter()
        .filter(|goal| !goal.relaxable)
        .cloned()
        .collect::<Vec<_>>();
    let optional_goals = goals
        .iter()
        .filter(|goal| goal.relaxable)
        .cloned()
        .collect::<Vec<_>>();

    let mut accepted = required_goals.clone();
    if !required_goals.is_empty() {
        let requests = requests_for_goals(&required_goals, lock_versions);
        if let Err(error) = simulate_goal_set(context, &requests) {
            trace.push("best_effort", TraceLevel::Error, error.to_string());
            let rejected = required_goals
                .iter()
                .map(|goal| UnsatEntry {
                    goal_id: Some(goal.id.clone()),
                    requested: goal.request_key(),
                    failure_class: FailureClass::AptSimulationFailed,
                    message: error.to_string(),
                    searched_candidates: Vec::new(),
                    violated_constraints: vec![error.to_string()],
                    dropped_in_best_effort: false,
                })
                .collect();

            return Ok(GoalSelection {
                goals: Vec::new(),
                rejected,
                simulation: empty_simulation(),
            });
        }
    }

    let mut rejected = Vec::new();
    for goal in optional_goals {
        let mut trial = accepted.clone();
        trial.push(goal.clone());
        let requests = requests_for_goals(&trial, lock_versions);
        match simulate_goal_set(context, &requests) {
            Ok(_) => {
                trace.push(
                    "best_effort",
                    TraceLevel::Info,
                    format!("accepted optional goal {}", goal.package),
                );
                accepted.push(goal);
            }
            Err(error) => {
                trace.push(
                    "best_effort",
                    TraceLevel::Warning,
                    format!("dropped goal {}: {error}", goal.package),
                );
                rejected.push(UnsatEntry {
                    goal_id: Some(goal.id.clone()),
                    requested: goal.request_key(),
                    failure_class: FailureClass::AptSimulationFailed,
                    message: error.to_string(),
                    searched_candidates: Vec::new(),
                    violated_constraints: vec![error.to_string()],
                    dropped_in_best_effort: true,
                });
            }
        }
    }

    let mut revisited = Vec::new();
    for entry in rejected {
        let Some(goal) = goals
            .iter()
            .find(|goal| Some(&goal.id) == entry.goal_id.as_ref())
        else {
            revisited.push(entry);
            continue;
        };

        let mut trial = accepted.clone();
        trial.push(goal.clone());
        let requests = requests_for_goals(&trial, lock_versions);
        match simulate_goal_set(context, &requests) {
            Ok(_) => {
                trace.push(
                    "best_effort",
                    TraceLevel::Info,
                    format!("recovered goal {}", goal.package),
                );
                accepted.push(goal.clone());
            }
            Err(_) => revisited.push(entry),
        }
    }

    let simulation = if accepted.is_empty() {
        empty_simulation()
    } else {
        simulate_goal_set(context, &requests_for_goals(&accepted, lock_versions))?
    };

    Ok(GoalSelection {
        goals: accepted,
        rejected: revisited,
        simulation,
    })
}

fn simulate_goal_set(context: &DebianContext, requests: &[String]) -> Result<AptSimulation> {
    if requests.is_empty() && context.local_debs.is_empty() {
        return Ok(empty_simulation());
    }
    context.simulate_install(requests)
}

fn collect_goals(args: &ResolveArgs, trace: &mut TraceReport) -> Result<Vec<Goal>> {
    let mut goals = Vec::new();

    if let Some(manifest_path) = &args.manifest {
        let manifest_goals = manifest::resolve_manifest_goals(
            manifest_path,
            &args.platform,
            &args.manager,
            args.bundle.as_deref(),
            args.host.as_deref(),
            &args.features,
        )?;
        trace.push(
            "manifest",
            TraceLevel::Info,
            format!("loaded {} goal(s) from manifest", manifest_goals.len()),
        );
        goals.extend(manifest_goals);
    }

    if let Some(request_file) = &args.request_file {
        let direct_goals = load_request_goals(request_file)?;
        trace.push(
            "requests",
            TraceLevel::Info,
            format!("loaded {} goal(s) from request file", direct_goals.len()),
        );
        goals.extend(direct_goals);
    }

    if goals.is_empty() {
        bail!("no package goals were supplied; provide --manifest or --request-file")
    }

    dedupe_goals(goals)
}

fn dedupe_goals(goals: Vec<Goal>) -> Result<Vec<Goal>> {
    let mut seen = BTreeSet::new();
    let mut output = Vec::new();

    for goal in goals {
        let key = goal.request_key();
        if seen.insert(key) {
            output.push(goal);
        }
    }

    Ok(output)
}

fn load_request_goals(path: &Path) -> Result<Vec<Goal>> {
    let raw = fs::read_to_string(path)
        .with_context(|| format!("failed to read request file {}", path.display()))?;

    match path.extension().and_then(OsStr::to_str) {
        Some("json") => {
            if let Ok(requests) = serde_json::from_str::<DirectRequestFile>(&raw) {
                return Ok(requests.goals);
            }

            let plan =
                serde_json::from_str::<crate::model::RequestArtifact>(&raw).with_context(|| {
                    format!(
                        "failed to parse request artifact JSON from {}",
                        path.display()
                    )
                })?;
            Ok(plan.goals)
        }
        _ => {
            let mut goals = Vec::new();
            for (index, line) in raw.lines().enumerate() {
                let trimmed = line.trim();
                if trimmed.is_empty() || trimmed.starts_with('#') {
                    continue;
                }

                let (package, version) = manifest::parse_package_request(trimmed);
                goals.push(Goal {
                    id: format!("request:{}:{package}", index + 1),
                    package,
                    version,
                    manager: Some("apt".to_string()),
                    group: None,
                    source: format!("request:{}", path.display()),
                    strict: true,
                    relaxable: false,
                    mapped_from: None,
                });
            }
            Ok(goals)
        }
    }
}

fn load_lock_versions(path: Option<&Path>) -> Result<HashMap<String, String>> {
    let Some(path) = path else {
        return Ok(HashMap::new());
    };

    let raw = fs::read_to_string(path)
        .with_context(|| format!("failed to read lockfile {}", path.display()))?;
    let plan = serde_json::from_str::<PlanLock>(&raw)
        .with_context(|| format!("failed to parse JSON lockfile {}", path.display()))?;

    let mut locks = HashMap::new();
    for entry in plan.selected {
        locks.insert(entry.package, entry.version);
    }
    Ok(locks)
}

fn requests_for_goals(goals: &[Goal], lock_versions: &HashMap<String, String>) -> Vec<String> {
    let mut requests = goals
        .iter()
        .map(|goal| {
            let version = lock_versions
                .get(&goal.package)
                .cloned()
                .or_else(|| goal.version.clone());

            match version {
                Some(version) => format!("{}={version}", goal.package),
                None => goal.package.clone(),
            }
        })
        .collect::<Vec<_>>();
    requests.sort();
    requests.dedup();
    requests
}

fn build_lock_entries(
    context: &DebianContext,
    goals: &[Goal],
    _lock_versions: &HashMap<String, String>,
    simulation: &AptSimulation,
    snapshot: Option<&str>,
) -> Result<Vec<LockEntry>> {
    let mut by_package: IndexMap<String, LockEntry> = IndexMap::new();

    for atom in &simulation.installed {
        by_package.insert(
            atom.package.clone(),
            LockEntry {
                package: atom.package.clone(),
                version: atom.version.clone(),
                architecture: atom.architecture.clone(),
                origin: atom.origin.clone(),
                component: atom.component.clone(),
                snapshot: atom
                    .snapshot
                    .clone()
                    .or_else(|| snapshot.map(str::to_string)),
                requested_by: Vec::new(),
                mapped_from: Vec::new(),
                local_deb: atom.local_deb.clone(),
            },
        );
    }

    for goal in goals {
        // Only pin packages that APT actually plans to install or upgrade in the current
        // machine state. Bootstrap helpers may preinstall toolchain packages like curl/gcc,
        // and re-resolving them here can lock versions that are no longer available for a
        // fresh apt-get install simulation.
        if let Some(entry) = by_package.get_mut(&goal.package) {
            if !entry.requested_by.contains(&goal.id) {
                entry.requested_by.push(goal.id.clone());
            }
            if let Some(mapped_from) = &goal.mapped_from {
                if !entry.mapped_from.contains(mapped_from) {
                    entry.mapped_from.push(mapped_from.clone());
                }
            }
        }
    }

    for local_deb in &context.local_debs {
        by_package
            .entry(local_deb.package.clone())
            .or_insert_with(|| LockEntry {
                package: local_deb.package.clone(),
                version: local_deb.version.clone(),
                architecture: local_deb.architecture.clone(),
                origin: Some("local-deb".to_string()),
                component: Some("local".to_string()),
                snapshot: snapshot.map(str::to_string),
                requested_by: Vec::new(),
                mapped_from: Vec::new(),
                local_deb: Some(local_deb.clone()),
            });
    }

    let mut entries = by_package.into_values().collect::<Vec<_>>();
    entries.sort_by(|left, right| left.package.cmp(&right.package));
    Ok(entries)
}

fn build_apt_plan(
    lock_entries: &[LockEntry],
    local_debs: &[crate::model::LocalDebSummary],
) -> Vec<String> {
    let mut plan = local_debs
        .iter()
        .map(|deb| deb.path.clone())
        .collect::<Vec<_>>();

    for entry in lock_entries {
        if entry.local_deb.is_some() {
            continue;
        }
        plan.push(format!("{}={}", entry.package, entry.version));
    }

    plan.sort();
    plan.dedup();
    plan
}

fn build_metadata(args: &ResolveArgs) -> PlanMetadata {
    let mut metadata = PlanMetadata::new("resolve", args.platform.clone(), args.manager.clone());
    metadata.best_effort = args.best_effort;
    metadata.manifest = args
        .manifest
        .as_ref()
        .map(|path| path.display().to_string());
    metadata.bundle = args.bundle.clone();
    metadata.host = args.host.clone();
    metadata.features = args.features.clone();
    metadata.snapshot = args.snapshot.clone();
    metadata.sources_list = args
        .sources_list
        .as_ref()
        .map(|path| path.display().to_string());
    metadata
}

fn empty_simulation() -> AptSimulation {
    AptSimulation {
        stdout: String::new(),
        stderr: String::new(),
        installed: Vec::new(),
        command: Vec::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builds_exact_requests_from_lock_versions() {
        let goals = vec![Goal {
            id: "goal:1".to_string(),
            package: "fd-find".to_string(),
            version: None,
            manager: Some("apt".to_string()),
            group: None,
            source: "test".to_string(),
            strict: true,
            relaxable: false,
            mapped_from: None,
        }];
        let mut locks = HashMap::new();
        locks.insert("fd-find".to_string(), "9.0".to_string());

        let requests = requests_for_goals(&goals, &locks);
        assert_eq!(requests, vec!["fd-find=9.0".to_string()]);
    }
}
