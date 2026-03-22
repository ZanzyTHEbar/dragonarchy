pub mod arch;
pub mod cli;
pub mod debian;
pub mod manifest;
pub mod model;
pub mod output;
pub mod solver;
pub mod verify;

use std::process::ExitCode;

use anyhow::Context;
use clap::Parser;

use crate::cli::{Cli, Commands};
use crate::model::ResolutionStatus;
use crate::output::ArtifactPaths;

const EXIT_GENERAL_FAILURE: u8 = 1;
const EXIT_RESOLUTION_FAILURE: u8 = 3;
const EXIT_VERIFICATION_FAILURE: u8 = 4;
const EXIT_MAPPING_FAILURE: u8 = 5;

pub fn main_exit_code() -> ExitCode {
    match run_cli() {
        Ok(code) => ExitCode::from(code),
        Err(error) => {
            eprintln!("pkgsolve: {error:#}");
            ExitCode::from(EXIT_GENERAL_FAILURE)
        }
    }
}

fn run_cli() -> anyhow::Result<u8> {
    let cli = Cli::parse();
    execute(cli)
}

pub fn execute(cli: Cli) -> anyhow::Result<u8> {
    match cli.command {
        Commands::Resolve(args) => {
            let outcome = solver::resolve(&args).context("resolve command failed")?;
            let paths = ArtifactPaths::new(&args.out);

            output::write_plan_artifacts(
                &paths,
                &outcome.plan,
                &outcome.unsat,
                &outcome.trace,
                &outcome.apt_plan,
                &outcome.preferences,
            )?;
            output::print_resolve_summary(
                &paths,
                &outcome.plan.status,
                outcome.unsat.entries.len(),
            );

            let exit_code = match outcome.plan.status {
                ResolutionStatus::Satisfiable => 0,
                ResolutionStatus::PartiallySatisfiable if args.best_effort => 0,
                ResolutionStatus::PartiallySatisfiable | ResolutionStatus::Unsatisfiable => {
                    EXIT_RESOLUTION_FAILURE
                }
            };

            Ok(exit_code)
        }
        Commands::Verify(args) => {
            let outcome = verify::verify(&args).context("verify command failed")?;
            let paths = ArtifactPaths::new(&args.out);

            output::write_plan_artifacts(
                &paths,
                &outcome.plan,
                &outcome.unsat,
                &outcome.trace,
                &outcome.apt_plan,
                &outcome.preferences,
            )?;
            output::print_verify_summary(&paths, outcome.unsat.entries.len());

            if outcome.unsat.entries.is_empty() {
                Ok(0)
            } else {
                Ok(EXIT_VERIFICATION_FAILURE)
            }
        }
        Commands::Map(args) => {
            let outcome = arch::map_arch_packages(&args).context("map command failed")?;
            let paths = ArtifactPaths::new(&args.out);

            output::write_map_artifacts(&paths, &outcome.requests, &outcome.unsat, &outcome.trace)?;
            output::print_map_summary(&paths, outcome.unsat.entries.len());

            if outcome.unsat.entries.is_empty() || args.best_effort {
                Ok(0)
            } else {
                Ok(EXIT_MAPPING_FAILURE)
            }
        }
    }
}
