//! lib.rs - Flutter Rust Bridge v2 entry point.
//!
//! FRB v2 rules:
//!     1. This file must declare `mod api:` - codegen scans src/api/*.rs
//!     2. Do not put bare `#[frb]` on structs/enums - codegen finds them automatically.
//!     3. `#[frb(...)]` is only used to *modify* behaviour:
//!         #[frb(sync)] - make the Dart call synchronous
//!         #[frb(ignore)] - hide a public item from Dart
//!         #[frb(non_final)] - make a struct field mutable in Dart
//!     4. The `flutter_rust_bridge_codegen generate` command reads src/api/**/*.rs
//!        and produces lib/src/rust in the Flutter project.

// Re-export the generated init hook (required by FRB v2 runtime).
pub use flutter_rust_bridge::for_generated::byteorder;

mod api; // codegen scans this module