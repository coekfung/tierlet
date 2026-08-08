//! Lifecycle management for the embedded EasyTier runtime.
//!
//! TierletCore owns a Tokio runtime and an EasyTier `NetworkInstanceManager`.
//! The daemon initializes the runtime once at startup and destroys it on exit.
//! All Tokio and EasyTier types stay inside this module; only simple records,
//! plain errors, and functions cross the UniFFI boundary.

use std::sync::{Arc, Mutex, MutexGuard};

use anyhow::{Context, anyhow};
use easytier::instance_manager::NetworkInstanceManager;
use thiserror::Error;
use tokio::runtime::{Builder, Runtime};

/// Snapshot of the embedded EasyTier runtime state.
#[derive(uniffi::Record)]
pub struct RuntimeStatus {
    pub initialized: bool,
    pub easy_tier_version: String,
}

/// Errors surfaced to the daemon host.
///
/// Internal failures are wrapped as [`anyhow::Error`] and flattened to their
/// message at the UniFFI boundary.
#[derive(Debug, Error, uniffi::Error)]
#[uniffi(flat_error)]
pub enum TierletError {
    /// A runtime is already running; call `destroy_runtime` first.
    #[error("runtime already initialized")]
    AlreadyInitialized,
    /// No runtime exists; call `initialize_runtime` first.
    #[error("runtime not initialized")]
    NotInitialized,
    /// An unexpected failure inside the core.
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// The embedded EasyTier runtime: a Tokio runtime plus the multi-instance
/// manager. Fields are only read once later phases add network operations;
/// for now the struct exists to own both objects for their lifetimes.
#[expect(dead_code)]
struct TierletRuntime {
    rt: Runtime,
    manager: Arc<NetworkInstanceManager>,
}

static RUNTIME: Mutex<Option<TierletRuntime>> = Mutex::new(None);

fn lock_runtime() -> Result<MutexGuard<'static, Option<TierletRuntime>>, TierletError> {
    RUNTIME
        .lock()
        .map_err(|_| TierletError::Internal(anyhow!("runtime state lock poisoned")))
}

/// Initializes the EasyTier runtime: builds the Tokio runtime (multi-threaded
/// with all drivers, mirroring the official daemon) plus the EasyTier instance
/// manager, and commits them to the global state. Fails with
/// `AlreadyInitialized` if a runtime is already running.
#[uniffi::export]
pub fn initialize_runtime() -> Result<(), TierletError> {
    let mut guard = lock_runtime()?;
    if guard.is_some() {
        return Err(TierletError::AlreadyInitialized);
    }

    let rt = Builder::new_multi_thread()
        .enable_all()
        .build()
        .context("failed to build Tokio runtime")
        .map_err(TierletError::from)?;
    let manager = Arc::new(NetworkInstanceManager::new());

    *guard = Some(TierletRuntime { rt, manager });
    Ok(())
}

/// Destroys the EasyTier runtime, stopping all instances and freeing the
/// Tokio runtime. The core can be re-initialized afterwards. Fails with
/// `NotInitialized` if no runtime is running.
#[uniffi::export]
pub fn destroy_runtime() -> Result<(), TierletError> {
    let mut guard = lock_runtime()?;
    match guard.take() {
        Some(_) => Ok(()),
        None => Err(TierletError::NotInitialized),
    }
}

/// Reports whether a runtime is initialized. Safe to call at any time.
#[uniffi::export]
pub fn runtime_status() -> RuntimeStatus {
    let guard = RUNTIME
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    RuntimeStatus {
        initialized: guard.is_some(),
        easy_tier_version: easytier::VERSION.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex as StdMutex;
    use std::thread;

    /// Serializes tests that touch the global runtime state, since `cargo test`
    /// runs tests in parallel threads.
    static TEST_LOCK: StdMutex<()> = StdMutex::new(());

    /// Runs `body` on a clean slate and destroys the runtime afterwards.
    fn with_clean_runtime<T>(body: impl FnOnce() -> T) -> T {
        let _guard = TEST_LOCK
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let _ = destroy_runtime();
        let result = body();
        let _ = destroy_runtime();
        result
    }

    #[test]
    fn status_reports_uninitialized_by_default() {
        with_clean_runtime(|| {
            let status = runtime_status();
            assert!(!status.initialized);
            // The git build appends the commit hash: "2.6.4-8428a89d".
            assert!(status.easy_tier_version.starts_with("2.6.4"));
        });
    }

    #[test]
    fn initialize_then_status_reports_initialized() {
        with_clean_runtime(|| {
            initialize_runtime().unwrap();
            let status = runtime_status();
            assert!(status.initialized);
            assert!(status.easy_tier_version.starts_with("2.6.4"));
        });
    }

    #[test]
    fn double_initialize_fails_with_already_initialized() {
        with_clean_runtime(|| {
            initialize_runtime().unwrap();
            assert!(matches!(
                initialize_runtime(),
                Err(TierletError::AlreadyInitialized)
            ));
        });
    }

    #[test]
    fn destroy_returns_to_uninitialized() {
        with_clean_runtime(|| {
            initialize_runtime().unwrap();
            destroy_runtime().unwrap();
            assert!(!runtime_status().initialized);
        });
    }

    #[test]
    fn destroy_without_initialize_fails_with_not_initialized() {
        with_clean_runtime(|| {
            assert!(matches!(
                destroy_runtime(),
                Err(TierletError::NotInitialized)
            ));
        });
    }

    #[test]
    fn reinitializes_after_destroy() {
        with_clean_runtime(|| {
            for _ in 0..3 {
                initialize_runtime().unwrap();
                assert!(runtime_status().initialized);
                destroy_runtime().unwrap();
                assert!(!runtime_status().initialized);
            }
        });
    }

    #[test]
    fn concurrent_initialize_allows_exactly_one() {
        with_clean_runtime(|| {
            let start = std::sync::Arc::new(std::sync::Barrier::new(2));
            let mut handles = Vec::new();
            for _ in 0..2 {
                let start = start.clone();
                handles.push(thread::spawn(move || {
                    start.wait();
                    initialize_runtime()
                }));
            }
            let results: Vec<_> = handles.into_iter().map(|h| h.join().unwrap()).collect();
            let successes = results.iter().filter(|result| result.is_ok()).count();
            assert_eq!(successes, 1, "exactly one initialize must win");
        });
    }
}
