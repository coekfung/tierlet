uniffi::setup_scaffolding!();

/// Version of the API shared with the macOS daemon host.
#[uniffi::export]
pub fn tierlet_core_abi_version() -> u32 {
    1
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exposes_current_abi_version() {
        assert_eq!(tierlet_core_abi_version(), 1);
    }
}
