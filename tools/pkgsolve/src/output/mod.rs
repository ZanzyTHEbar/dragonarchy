use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use serde::Serialize;

use crate::model::{PlanLock, RequestArtifact, ResolutionStatus, TraceReport, UnsatReport};

#[derive(Debug, Clone)]
pub struct ArtifactPaths {
    pub dir: PathBuf,
    pub plan_lock: PathBuf,
    pub plan_unsat: PathBuf,
    pub plan_trace: PathBuf,
    pub plan_apt: PathBuf,
    pub plan_preferences: PathBuf,
    pub plan_requests: PathBuf,
}

impl ArtifactPaths {
    pub fn new(out_dir: &Path) -> Self {
        Self {
            dir: out_dir.to_path_buf(),
            plan_lock: out_dir.join("plan.lock.json"),
            plan_unsat: out_dir.join("plan.unsat.json"),
            plan_trace: out_dir.join("plan.trace.json"),
            plan_apt: out_dir.join("plan.apt.txt"),
            plan_preferences: out_dir.join("plan.preferences"),
            plan_requests: out_dir.join("plan.requests.json"),
        }
    }

    fn ensure_dir(&self) -> Result<()> {
        fs::create_dir_all(&self.dir)
            .with_context(|| format!("failed to create artifact directory {}", self.dir.display()))
    }
}

pub fn write_plan_artifacts(
    paths: &ArtifactPaths,
    plan: &PlanLock,
    unsat: &UnsatReport,
    trace: &TraceReport,
    apt_plan: &[String],
    preferences: &str,
) -> Result<()> {
    paths.ensure_dir()?;
    write_json(&paths.plan_lock, plan)?;
    write_json(&paths.plan_unsat, unsat)?;
    write_json(&paths.plan_trace, trace)?;
    write_text_lines(&paths.plan_apt, apt_plan)?;
    write_text(&paths.plan_preferences, preferences)?;
    Ok(())
}

pub fn write_map_artifacts(
    paths: &ArtifactPaths,
    requests: &RequestArtifact,
    unsat: &UnsatReport,
    trace: &TraceReport,
) -> Result<()> {
    paths.ensure_dir()?;
    write_json(&paths.plan_requests, requests)?;
    write_json(&paths.plan_unsat, unsat)?;
    write_json(&paths.plan_trace, trace)?;
    write_text(&paths.plan_preferences, "")?;
    write_text_lines(&paths.plan_apt, &[])?;
    Ok(())
}

pub fn print_resolve_summary(paths: &ArtifactPaths, status: &ResolutionStatus, unsat_count: usize) {
    println!("pkgsolve resolve status: {}", format_status(status));
    println!("artifacts: {}", paths.dir.display());
    println!("lock: {}", paths.plan_lock.display());
    println!("unsat: {}", paths.plan_unsat.display());
    println!("trace: {}", paths.plan_trace.display());
    println!("apt: {}", paths.plan_apt.display());
    println!("preferences: {}", paths.plan_preferences.display());
    if unsat_count > 0 {
        println!("unsatisfied entries: {unsat_count}");
    }
}

pub fn print_verify_summary(paths: &ArtifactPaths, unsat_count: usize) {
    println!(
        "pkgsolve verify status: {}",
        if unsat_count == 0 {
            "verified"
        } else {
            "failed"
        }
    );
    println!("artifacts: {}", paths.dir.display());
    println!("lock: {}", paths.plan_lock.display());
    println!("unsat: {}", paths.plan_unsat.display());
    println!("trace: {}", paths.plan_trace.display());
    println!("apt: {}", paths.plan_apt.display());
}

pub fn print_map_summary(paths: &ArtifactPaths, unsat_count: usize) {
    println!(
        "pkgsolve map status: {}",
        if unsat_count == 0 {
            "mapped"
        } else {
            "partial"
        }
    );
    println!("artifacts: {}", paths.dir.display());
    println!("requests: {}", paths.plan_requests.display());
    println!("unsat: {}", paths.plan_unsat.display());
    println!("trace: {}", paths.plan_trace.display());
}

fn format_status(status: &ResolutionStatus) -> &'static str {
    match status {
        ResolutionStatus::Satisfiable => "satisfiable",
        ResolutionStatus::PartiallySatisfiable => "partially_satisfiable",
        ResolutionStatus::Unsatisfiable => "unsatisfiable",
    }
}

fn write_json<T: Serialize>(path: &Path, value: &T) -> Result<()> {
    let content = serde_json::to_string_pretty(value)
        .with_context(|| format!("failed to serialize {}", path.display()))?;
    write_text(path, &content)
}

fn write_text_lines(path: &Path, lines: &[String]) -> Result<()> {
    write_text(path, &lines.join("\n"))
}

fn write_text(path: &Path, content: &str) -> Result<()> {
    fs::write(path, content).with_context(|| format!("failed to write {}", path.display()))
}
