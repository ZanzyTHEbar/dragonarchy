use std::path::PathBuf;

use pkgsolve::arch;
use pkgsolve::cli::MapArgs;

#[test]
fn maps_supported_packages_and_emits_unsat_for_unsupported_ones() {
    let arch_input =
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/arch/packages.txt");
    let metadata_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/debian");

    let outcome = arch::map_arch_packages(&MapArgs {
        arch_input,
        mapping_file: None,
        metadata_dir: Some(metadata_dir),
        best_effort: true,
        out: PathBuf::from(".artifacts/pkgsolve/test-map"),
    })
    .expect("mapping should succeed");

    assert!(outcome
        .requests
        .goals
        .iter()
        .any(|goal| goal.package == "fd-find"));
    assert!(outcome
        .requests
        .goals
        .iter()
        .any(|goal| goal.package == "joplin-desktop"));
    assert!(outcome
        .unsat
        .entries
        .iter()
        .any(|entry| entry.requested == "walker-bin"));
}
