use std::path::PathBuf;

use pkgsolve::debian::DebianContext;

#[test]
fn loads_candidates_from_packages_fixture() {
    let fixture_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/debian");
    let context = DebianContext::new(Some(&fixture_dir), None, None, Vec::new(), Vec::new())
        .expect("fixture metadata should load");

    let alpha = context
        .lookup_candidates("alpha")
        .expect("alpha lookup should succeed");
    assert_eq!(alpha.len(), 1);
    assert_eq!(alpha[0].version, "1.0-1");
    assert!(alpha[0].depends.iter().any(|dep| dep.contains("beta")));
}
