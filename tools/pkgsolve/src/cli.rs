use std::path::PathBuf;

use clap::{Args, Parser, Subcommand};

#[derive(Debug, Parser)]
#[command(
    name = "pkgsolve",
    version,
    about = "Plan, verify, and translate Debian package intents"
)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Debug, Subcommand)]
pub enum Commands {
    Resolve(Box<ResolveArgs>),
    Verify(Box<VerifyArgs>),
    Map(Box<MapArgs>),
}

#[derive(Debug, Clone, Args)]
pub struct ResolveArgs {
    #[arg(long)]
    pub manifest: Option<PathBuf>,

    #[arg(long)]
    pub bundle: Option<String>,

    #[arg(long, default_value = "debian")]
    pub platform: String,

    #[arg(long, default_value = "apt")]
    pub manager: String,

    #[arg(long)]
    pub host: Option<String>,

    #[arg(long = "feature")]
    pub features: Vec<String>,

    #[arg(long)]
    pub request_file: Option<PathBuf>,

    #[arg(long)]
    pub lockfile: Option<PathBuf>,

    #[arg(long)]
    pub pins: Option<PathBuf>,

    #[arg(long)]
    pub local_debs: Option<PathBuf>,

    #[arg(long)]
    pub metadata_dir: Option<PathBuf>,

    #[arg(long)]
    pub snapshot: Option<String>,

    #[arg(long)]
    pub sources_list: Option<PathBuf>,

    #[arg(long)]
    pub best_effort: bool,

    #[arg(long, default_value = ".artifacts/pkgsolve/resolve")]
    pub out: PathBuf,
}

#[derive(Debug, Clone, Args)]
pub struct VerifyArgs {
    #[arg(long)]
    pub plan: PathBuf,

    #[arg(long)]
    pub metadata_dir: Option<PathBuf>,

    #[arg(long)]
    pub sources_list: Option<PathBuf>,

    #[arg(long)]
    pub pins: Option<PathBuf>,

    #[arg(long, default_value = ".artifacts/pkgsolve/verify")]
    pub out: PathBuf,
}

#[derive(Debug, Clone, Args)]
pub struct MapArgs {
    #[arg(long)]
    pub arch_input: PathBuf,

    #[arg(long)]
    pub mapping_file: Option<PathBuf>,

    #[arg(long)]
    pub metadata_dir: Option<PathBuf>,

    #[arg(long)]
    pub best_effort: bool,

    #[arg(long, default_value = ".artifacts/pkgsolve/map")]
    pub out: PathBuf,
}
