use std::path::PathBuf;

use pkgsolve::manifest;

#[test]
fn resolves_real_minimal_bundle_from_repo_manifest() {
    let manifest_path =
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../scripts/install/deps.manifest.toml");

    let goals = manifest::resolve_manifest_goals(
        &manifest_path,
        "debian",
        "apt",
        Some("minimal"),
        Some("headless"),
        &[],
    )
    .expect("manifest goals should resolve");

    assert!(goals.iter().any(|goal| goal.package == "vim"));
    assert!(goals.iter().any(|goal| goal.package == "git"));
    assert!(goals
        .iter()
        .all(|goal| goal.manager.as_deref() == Some("apt")));
}
