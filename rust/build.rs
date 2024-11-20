#[allow(dead_code)]
fn add_lib(name: impl AsRef<str>, _static: bool) {
    #[cfg(not(test))]
    println!(
        "cargo:rustc-link-lib={}{}",
        if _static { "static=" } else { "" },
        name.as_ref()
    );
}

/// Adds a temporary workaround for an issue with the Rust compiler and Android
/// in x86_64 devices: https://github.com/rust-lang/rust/issues/109717.
/// The workaround comes from: https://github.com/mozilla/application-services/pull/5442
fn setup_x86_64_android_workaround() {
    use std::env;
    let target_os = env::var("CARGO_CFG_TARGET_OS").expect("CARGO_CFG_TARGET_OS not set");
    let target_arch = env::var("CARGO_CFG_TARGET_ARCH").expect("CARGO_CFG_TARGET_ARCH not set");
    if target_arch == "x86_64" && target_os == "android" {
        let android_ndk_root = env::var("ANDROID_NDK_ROOT").expect("ANDROID_NDK_ROOT not set");
        let build_os = match env::consts::OS {
            "linux" => "linux",
            "macos" => "darwin",
            "windows" => "windows",
            _ => panic!(
                "Unsupported OS. You must use either Linux, MacOS or Windows to build the crate."
            ),
        };
        const DEFAULT_CLANG_VERSION: &str = "17.0.2";
        let clang_version =
            env::var("NDK_CLANG_VERSION").unwrap_or_else(|_| DEFAULT_CLANG_VERSION.to_owned());
        let linux_x86_64_lib_dir = format!(
            "toolchains/llvm/prebuilt/{build_os}-x86_64/lib/clang/{clang_version}/lib/linux/"
        );
        println!("cargo:rustc-link-search={android_ndk_root}/{linux_x86_64_lib_dir}");
        println!("cargo:rustc-link-lib=static=clang_rt.builtins-x86_64-android");
    }
}

#[allow(dead_code, unused, unused_variables)]
fn main() {
    // setup_x86_64_android_workaround();
    let target = std::env::var("TARGET").expect("ERR: Could not check the target for the build.");

    if target.contains("android") {
        add_lib("c++_shared", false);
    }
}
