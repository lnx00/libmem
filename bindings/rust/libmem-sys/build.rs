use std::env;

#[cfg(any(feature = "fetch"))]
#[allow(dead_code)]
struct FetchInfo {
    // The following information is presented in a way
    // that matches libmem's release archive information.
    version: String,
    target_os: String,
    target_arch: String,
    target_env: String,
    release_target: String,
    archive_filename: String,
    download_url: String,
}

#[cfg(feature = "fetch")]
fn get_fetch_information() -> FetchInfo {
    // Get cargo variables
    let version = env::var("CARGO_PKG_VERSION").unwrap();
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap();
    let mut target_arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    let mut target_env = env::var("CARGO_CFG_TARGET_ENV").unwrap();
    let target_abi = env::var("CARGO_CFG_TARGET_ABI").unwrap();

    // Patch architecture
    if target_arch == "x86" {
        target_arch = "i686".to_string();
    }

    // Patch target environment
    if target_os == "linux" && cfg!(feature = "static") {
        // Always use musl for static linking on Linux
        target_env = "musl".to_owned();
    } else if target_os == "windows" && target_env == "gnu" {
        // Verify MinGW and Runtime (MSVCRT or UCRT)
        if target_abi == "llvm" {
            target_env = format!("{}-{}", target_env, "ucrt");
        } else {
            target_env = format!("{}-{}", target_env, "msvcrt");
        }
    };

    // Patch build type
    let build_type = if target_env == "msvc" {
        "static-mt"
    } else {
        "static"
    };

    // Format archive prefix
    // NOTE: target_env can be empty (e.g. on Android), in which case it is omitted
    let release_target = if target_env.is_empty() {
        format!(
            "libmem-{}-{}-{}-{}",
            version, target_arch, target_os, build_type
        )
    } else {
        format!(
            "libmem-{}-{}-{}-{}-{}",
            version, target_arch, target_os, target_env, build_type
        )
    };

    // Format archive URL
    let archive_ext = "tar.gz";
    let archive_filename = format!("{}.{}", release_target, archive_ext);
    let repo = env::var("LIBMEM_REPO").unwrap_or_else(|_| "rdbo/libmem".to_string());
    let download_url = env::var("LIBMEM_DOWNLOAD_URL").unwrap_or_else(|_| {
        format!(
            "https://github.com/{}/releases/download/{}/{}",
            repo, version, archive_filename
        )
    });

    return FetchInfo {
        version,
        target_os,
        target_arch,
        target_env,
        release_target,
        archive_filename,
        download_url,
    };
}

/// Downloads and adds the libmem path as a search path for linking
// NOTE: This always fetches a static library
#[cfg(feature = "fetch")]
fn download_and_resolve_libmem() {
    use flate2::read::GzDecoder;
    use std::{
        fs::File,
        io::{self, Cursor},
        path::PathBuf,
    };
    use tar::Archive;

    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    // Get download URL
    let fetch_info = get_fetch_information();

    eprintln!("Download URL: {}", fetch_info.download_url);

    // Download archive if necessary
    let archive_path = out_dir.join(fetch_info.archive_filename);
    if !archive_path.exists() {
        let req = reqwest::blocking::get(&fetch_info.download_url).expect(&format!(
            "Failed to download libmem archive from: {}",
            fetch_info.download_url
        ));

        if !req.status().is_success() {
            panic!(
                "Request to download URL failed with code '{}': {}",
                req.status(),
                fetch_info.download_url
            );
        }

        let content = req.bytes().expect("Failed to get download content");
        eprintln!("Content size: {} bytes", content.len());

        let mut file = File::create(&archive_path).expect(&format!(
            "Failed to create libmem archive on path: {:?}",
            archive_path
        ));
        io::copy(&mut Cursor::new(content), &mut file)
            .expect("Failed to copy downloaded content to archive");
    }

    // Extract archive if necessary
    let archive_dir = out_dir.join(fetch_info.release_target);
    if !archive_dir.exists() {
        let tar_gz = File::open(&archive_path)
            .expect(&format!("Failed to open archive file: {:?}", archive_path));
        let tar = GzDecoder::new(tar_gz);
        let mut tar_archive = Archive::new(tar);
        tar_archive
            .unpack(out_dir)
            .expect("Failed to extract libmem archive");
    }

    // Properly add library path for linking
    let search_path = if fetch_info.target_os == "windows" {
        archive_dir.join("lib").join("release")
    } else {
        archive_dir.join("lib")
    };

    eprintln!("Search path: {}", search_path.display());
    println!("cargo:rustc-link-search={}", search_path.display());
}

#[cfg(feature = "test")]
fn run_tests() {
    use std::collections::HashMap;
    let test_cases = HashMap::from([
        // expected, [version, os, arch, env, abi]
        (
            "libmem-1337-x86_64-linux-musl-static",
            ["1337", "linux", "x86_64", "musl", ""],
        ),
        (
            "libmem-1337-x86_64-windows-gnu-msvcrt-static",
            ["1337", "windows", "x86_64", "gnu", ""],
        ),
        (
            "libmem-1337-x86_64-windows-gnu-ucrt-static",
            ["1337", "windows", "x86_64", "gnu", "llvm"],
        ),
        (
            "libmem-1337-aarch64-android-static",
            ["1337", "android", "aarch64", "", ""],
        ),
    ]);

    env::remove_var("LIBMEM_REPO");
    env::remove_var("LIBMEM_DOWNLOAD_URL");

    for (expected, cargo_vars) in test_cases {
        env::set_var("CARGO_PKG_VERSION", cargo_vars[0]);
        env::set_var("CARGO_CFG_TARGET_OS", cargo_vars[1]);
        env::set_var("CARGO_CFG_TARGET_ARCH", cargo_vars[2]);
        env::set_var("CARGO_CFG_TARGET_ENV", cargo_vars[3]);
        env::set_var("CARGO_CFG_TARGET_ABI", cargo_vars[4]);
        let fetch_info = get_fetch_information();
        assert_eq!(expected, fetch_info.release_target);
        assert_eq!(
            format!(
                "https://github.com/rdbo/libmem/releases/download/{}/{}.tar.gz",
                cargo_vars[0], expected
            ),
            fetch_info.download_url
        );
    }

    // Test custom repo
    env::set_var("LIBMEM_REPO", "test-user/my-libmem");
    let fetch_info = get_fetch_information();
    assert!(fetch_info
        .download_url
        .starts_with("https://github.com/test-user/my-libmem/releases/download/"));
    env::remove_var("LIBMEM_REPO");

    // Test custom download URL
    env::set_var("LIBMEM_DOWNLOAD_URL", "https://custom.site/archive.tar.gz");
    let fetch_info = get_fetch_information();
    assert_eq!("https://custom.site/archive.tar.gz", fetch_info.download_url);
    env::remove_var("LIBMEM_DOWNLOAD_URL");

    panic!("[libmem-sys] OK - build.rs tests have passed. Disable the 'test' feature to actually build.");
}

fn main() {
    println!("cargo:rerun-if-env-changed=LIBMEM_DIR");
    println!("cargo:rerun-if-env-changed=LIBMEM_REPO");
    println!("cargo:rerun-if-env-changed=LIBMEM_DOWNLOAD_URL");

    #[cfg(feature = "test")]
    run_tests();

    // TODO: Fix library not being looked up dynamically without "LIBMEM_DIR" set
    if let Ok(path) = env::var("LIBMEM_DIR") {
        println!("cargo:rustc-link-search=native={}", path);
    } else {
        #[cfg(feature = "fetch")]
        download_and_resolve_libmem();
    }

    // Resolve link dependencies
    if cfg!(feature = "static") {
        println!("cargo:rustc-link-lib=libmem");
    } else {
        println!("cargo:rustc-link-lib=dylib=libmem")
    }

    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap();
    let deps = if target_os == "windows" {
        vec!["user32", "psapi", "ntdll", "shell32"]
    } else if target_os == "linux" {
        vec!["dl", "m", "stdc++"]
    } else if target_os == "android" {
        vec!["dl", "m", "c++_shared"]
    } else if target_os == "freebsd" {
        vec!["dl", "kvm", "procstat", "elf", "m", "stdc++"]
    } else {
        vec![]
    };

    for dep in deps {
        println!("cargo:rustc-link-lib={}", dep);
    }
}
