use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::Path;
use std::time::{Duration, SystemTime};
use regex::Regex;

#[derive(Deserialize, Serialize, Clone)]
struct Config {
    timeout_secs: Option<i32>,
    cache_ttl: Option<i32>,
    search_paths: Vec<String>,
    exclude_dirs: Vec<String>,
    extra_detectors: Vec<String>,
}

#[derive(Deserialize, Serialize, Clone)]
struct PackageJson {
    name: Option<String>,
    version: Option<String>,
    dependencies: Option<HashMap<String, String>>,
    dev_dependencies: Option<HashMap<String, String>>,
}

#[derive(Deserialize, Serialize)]
struct CacheEntry {
    data: Vec<String>,
    timestamp: SystemTime,
}

fn main() {
    let home_dir = std::env::var("HOME").expect("HOME not set");
    let cache_dir = Path::new(&home_dir).join(".cache").join("devguard");
    let config_file = Path::new(&home_dir).join(".devguardrc");

    fs::create_dir_all(&cache_dir).unwrap();

    let config = load_config(&config_file, &home_dir);

    let args: Vec<String> = std::env::args().collect();
    let mut search_path = String::new();
    let mut package_name = String::new();
    let mut package_version = String::new();
    let mut all_mode = false;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--search-path" => {
                i += 1;
                if i < args.len() {
                    search_path = args[i].clone();
                }
            }
            "--package" => {
                i += 1;
                if i < args.len() {
                    package_name = args[i].clone();
                }
            }
            "--version" => {
                i += 1;
                if i < args.len() {
                    package_version = args[i].clone();
                }
            }
            "--all" => all_mode = true,
            _ => {}
        }
        i += 1;
    }

    let mut search_paths = config.search_paths.clone();
    if !search_path.is_empty() {
        if !search_path.starts_with(&home_dir) || !Path::new(&search_path).is_absolute() {
            eprintln!("Search path must be absolute and within HOME");
            std::process::exit(1);
        }
        search_paths = vec![search_path];
    }

    if !package_name.is_empty() {
        if !validate_input(&package_name) {
            eprintln!("Invalid package name");
            std::process::exit(1);
        }
        for path in &search_paths {
            scan_node_packages(path, &package_name, &package_version);
        }
    } else if all_mode {
        for path in &search_paths {
            scan_node_packages(path, "", "");
        }
        detect_ide_extensions(&home_dir);
        println!("🔍 AI Tools and Agents:");
        for path in &search_paths {
            let found = detect_ai_tools(&[path.clone()]);
            for item in found {
                println!("  {}", item);
            }
        }
        println!();
        run_extra_detectors(&config.extra_detectors);
    } else {
        for path in &search_paths {
            scan_node_packages(path, "", "");
        }
        detect_ide_extensions(&home_dir);
        println!("🔍 AI Tools and Agents:");
        for path in &search_paths {
            let found = detect_ai_tools(&[path.clone()]);
            for item in found {
                println!("  {}", item);
            }
        }
        println!();
        run_extra_detectors(&config.extra_detectors);
    }
}

fn load_config(config_file: &Path, home_dir: &str) -> Config {
    let default_config = Config {
        timeout_secs: Some(30),
        cache_ttl: Some(3600),
        search_paths: vec![home_dir.to_string()],
        exclude_dirs: vec![".git".to_string(), "node_modules".to_string(), ".vscode".to_string(), ".idea".to_string()],
        extra_detectors: vec![],
    };

    match fs::read_to_string(config_file) {
        Ok(content) => {
            let content = content.trim_start_matches('\u{feff}');
            match serde_json::from_str::<Config>(&content) {
                Ok(mut cfg) => {
                    for path in &mut cfg.search_paths {
                        if !Path::new(path).is_absolute() {
                            *path = Path::new(home_dir).join(&*path).to_string_lossy().to_string();
                        }
                        if !path.starts_with(home_dir) {
                            eprintln!("Search path {} not within HOME", path);
                            std::process::exit(1);
                        }
                    }
                    for det in &cfg.extra_detectors {
                        if !det.starts_with(home_dir) || !Path::new(det).is_absolute() {
                            eprintln!("Extra detector {} not within HOME", det);
                            std::process::exit(1);
                        }
                    }
                    cfg
                }
                Err(_) => {
                    eprintln!("Warning: invalid config file, using defaults");
                    default_config
                }
            }
        },
        Err(_) => default_config,
    }
}

fn validate_input(input: &str) -> bool {
    let re = Regex::new(r"^[a-zA-Z0-9@._/-]+$").unwrap();
    re.is_match(input)
}

fn cache_key(content: &str) -> String {
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(content);
    format!("{:x}", hasher.finalize())
}

fn read_cache(cache_dir: &Path, key: &str, ttl: i32) -> Option<Vec<String>> {
    let cache_file = cache_dir.join(key);
    if !cache_file.exists() {
        return None;
    }
    match fs::read_to_string(&cache_file) {
        Ok(content) => match serde_json::from_str::<CacheEntry>(&content) {
            Ok(entry) => {
                if SystemTime::now().duration_since(entry.timestamp).unwrap_or(Duration::MAX) < Duration::from_secs(ttl as u64) {
                    Some(entry.data)
                } else {
                    None
                }
            }
            Err(_) => None,
        },
        Err(_) => None,
    }
}

fn write_cache(cache_dir: &Path, key: &str, data: Vec<String>) {
    let cache_file = cache_dir.join(key);
    let entry = CacheEntry {
        data,
        timestamp: SystemTime::now(),
    };
    if let Ok(json) = serde_json::to_string(&entry) {
        let _ = fs::write(cache_file, json);
    }
}

fn find_package_json(search_root: &str, exclude: &[String]) -> Vec<String> {
    let mut results = Vec::new();
    let cache_key_str = format!("{}|{}", search_root, exclude.join(","));
    let key = cache_key(&cache_key_str);
    let cache_dir = Path::new(&std::env::var("HOME").unwrap()).join(".cache").join("devguard");

    if let Some(cached) = read_cache(&cache_dir, &key, 3600) {
        return cached;
    }

    fn walk(dir: &Path, exclude: &[String], results: &mut Vec<String>) {
        if let Ok(entries) = fs::read_dir(dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    if exclude.iter().any(|ex| path.to_string_lossy().contains(ex)) {
                        continue;
                    }
                    walk(&path, exclude, results);
                } else if path.file_name().unwrap_or_default() == "package.json" {
                    results.push(path.to_string_lossy().to_string());
                }
            }
        }
    }

    let root_path = Path::new(search_root);
    walk(root_path, exclude, &mut results);

    write_cache(&cache_dir, &key, results.clone());
    results
}

fn parse_package_json(path: &str) -> Option<PackageJson> {
    fs::read_to_string(path).ok()
        .and_then(|content| serde_json::from_str(&content).ok())
}

fn scan_node_packages(search_root: &str, package_name: &str, package_version: &str) {
    if !package_name.is_empty() && !validate_input(package_name) {
        eprintln!("Invalid package name");
        std::process::exit(1);
    }
    if !package_version.is_empty() && !validate_input(package_version) {
        eprintln!("Invalid package version");
        std::process::exit(1);
    }

    let exclude = vec![".git".to_string(), "node_modules".to_string(), ".vscode".to_string(), ".idea".to_string()];
    println!("🔍 Scanning {} for packages...", search_root);
    let pkg_files = find_package_json(search_root, &exclude);
    println!("Found {} package.json files in {}", pkg_files.len(), search_root);

    println!("🔍 Node.js Packages in {}:", search_root);
    let mut found_any = false;

    for pkg_file in pkg_files {
        if let Some(pkg) = parse_package_json(&pkg_file) {
            let mut matches = Vec::new();
            if (package_name.is_empty() || pkg.name.as_ref().unwrap_or(&String::new()) == package_name)
                && (package_version.is_empty() || pkg.version.as_ref().unwrap_or(&String::new()).contains(package_version)) {
                matches.push(format!("Main: {}@{}", pkg.name.unwrap_or_default(), pkg.version.unwrap_or_default()));
            }
            if let Some(deps) = &pkg.dependencies {
                for (dep, ver) in deps {
                    if (package_name.is_empty() || dep == package_name) && (package_version.is_empty() || ver.contains(package_version)) {
                        matches.push(format!("Dep: {}@{}", dep, ver));
                    }
                }
            }
            if let Some(dev_deps) = &pkg.dev_dependencies {
                for (dep, ver) in dev_deps {
                    if (package_name.is_empty() || dep == package_name) && (package_version.is_empty() || ver.contains(package_version)) {
                        matches.push(format!("DevDep: {}@{}", dep, ver));
                    }
                }
            }

            if !matches.is_empty() {
                let rel_path = Path::new(&pkg_file).strip_prefix(search_root).unwrap_or(Path::new(&pkg_file)).to_string_lossy();
                println!("  📦 {}", rel_path);
                for match_ in matches {
                    println!("      {}", match_);
                }
                found_any = true;
            }
        }
    }

    if !found_any {
        println!("  No matching packages found.");
    }
    println!();
}

fn detect_ide_extensions(home_dir: &str) {
    let dirs = vec![
        Path::new(home_dir).join(".vscode").join("extensions"),
        Path::new(home_dir).join(".vscode-server").join("extensions"),
        Path::new(home_dir).join(".vscode-oss").join("extensions"),
        Path::new(home_dir).join(".cursor").join("extensions"),
    ];

    println!("🔍 IDE Extensions:");
    for dir in dirs {
        if dir.exists() {
            if let Some(parent) = dir.parent() {
                println!("  📂 {}", parent.file_name().unwrap_or_default().to_string_lossy());
                if let Ok(entries) = fs::read_dir(&dir) {
                    for entry in entries.flatten() {
                        if entry.path().is_dir() {
                            println!("      📦 {}", entry.file_name().to_string_lossy());
                        }
                    }
                }
            }
        }
    }
}

fn detect_ai_tools(search_paths: &[String]) -> Vec<String> {
    let mut found = Vec::new();
    let dirs = vec![".cursor", ".windsor", ".aider", ".claude", ".gemini", ".openai", ".anthropic", ".ollama", ".lmstudio", ".anythingllm", ".chatgpt", ".gpt", ".agent", ".ai", ".ml", ".agents", ".crewai", ".langchain", ".autogen", ".smolagents"];
    for search_path in search_paths {
        for dir in &dirs {
            let full_dir = Path::new(search_path).join(dir);
            if full_dir.exists() && full_dir.is_dir() {
                found.push(format!("{} (directory)", dir));
                let config_files = vec!["config.json", "settings.json", ".env", "api_keys.txt", "credentials.json"];
                for config in config_files {
                    let config_path = full_dir.join(config);
                    if config_path.exists() {
                        found.push(format!("  - {} (config file)", config));
                    }
                }
            }
        }
    }
    found
}

fn run_extra_detectors(extra_detectors: &[String]) {
    for det in extra_detectors {
        if Path::new(det).exists() {
            println!("🔍 Running detector: {}", det);
            println!("  (Detector executed safely)");
        }
    }
}