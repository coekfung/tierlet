/// Version of the C ABI shared with the macOS daemon host.
#[unsafe(no_mangle)]
pub extern "C" fn tierlet_core_abi_version() -> u32 {
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
