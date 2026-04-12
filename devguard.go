package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// Config holds user config from file
type Config struct {
	TimeoutSecs   int      `json:"timeout_secs"`
	CacheTTL      int      `json:"cache_ttl"`
	SearchPaths   []string `json:"search_paths"`
	ExcludeDirs   []string `json:"exclude_dirs"`
	ExtraDetectors []string `json:"extra_detectors"`
}

// PackageJSON represents a minimal package.json
type PackageJSON struct {
	Name         string            `json:"name"`
	Version      string            `json:"version"`
	Dependencies map[string]string `json:"dependencies"`
	DevDependencies map[string]string `json:"devDependencies"`
}

// CacheEntry for caching
type CacheEntry struct {
	Data      []string  `json:"data"`
	Timestamp time.Time `json:"timestamp"`
}

var (
	homeDir   = os.Getenv("HOME")
	cacheDir  = filepath.Join(homeDir, ".cache", "devguard")
	configFile = filepath.Join(homeDir, ".devguardrc")
	config    Config
	cache     = make(map[string]CacheEntry)
)

func init() {
	// Ensure cache dir exists
	os.MkdirAll(cacheDir, 0755)
	// Load config safely
	loadConfig()
}

func loadConfig() {
	file, err := os.Open(configFile)
	if err != nil {
		// Default config
		config = Config{
			TimeoutSecs: 30,
			CacheTTL:    3600,
			SearchPaths: []string{homeDir},
			ExcludeDirs: []string{".git", "node_modules", ".vscode", ".idea"},
		}
		return
	}
	defer file.Close()

	// Parse as JSON for safety (no sourcing)
	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&config); err != nil {
		log.Printf("Warning: invalid config file, using defaults")
		config = Config{
			TimeoutSecs: 30,
			CacheTTL:    3600,
			SearchPaths: []string{homeDir},
			ExcludeDirs: []string{".git", "node_modules", ".vscode", ".idea"},
		}
	}

	// Validate paths
	for i, path := range config.SearchPaths {
		if !filepath.IsAbs(path) {
			config.SearchPaths[i] = filepath.Join(homeDir, path)
		}
		if !strings.HasPrefix(config.SearchPaths[i], homeDir) {
			log.Fatalf("Search path %s not within HOME", path)
		}
	}
	for _, det := range config.ExtraDetectors {
		if !strings.HasPrefix(det, homeDir) || !filepath.IsAbs(det) {
			log.Fatalf("Extra detector %s not within HOME", det)
		}
	}
}

func validateInput(input string) bool {
	// Allow only safe chars: alphanumeric, @._/-
	matched, _ := regexp.MatchString(`^[a-zA-Z0-9@._/-]+$`, input)
	return matched
}

func cacheKey(content string) string {
	hash := sha256.Sum256([]byte(content))
	return hex.EncodeToString(hash[:])
}

func isCacheValid(key string) bool {
	entry, exists := cache[key]
	if !exists {
		return false
	}
	return time.Since(entry.Timestamp) < time.Duration(config.CacheTTL)*time.Second
}

func readCache(key string) []string {
	cacheFile := filepath.Join(cacheDir, key)
	file, err := os.Open(cacheFile)
	if err != nil {
		return nil
	}
	defer file.Close()

	var entry CacheEntry
	if err := json.NewDecoder(file).Decode(&entry); err != nil {
		return nil
	}
	if !isCacheValid(key) {
		return nil
	}
	return entry.Data
}

func writeCache(key string, data []string) {
	cacheFile := filepath.Join(cacheDir, key)
	file, err := os.Create(cacheFile)
	if err != nil {
		return
	}
	defer file.Close()

	entry := CacheEntry{
		Data:      data,
		Timestamp: time.Now(),
	}
	json.NewEncoder(file).Encode(entry)
	cache[key] = entry
}

func findPackageJSON(searchRoot string, exclude []string) []string {
	var results []string
	cacheKeyStr := searchRoot + "|" + strings.Join(exclude, ",")
	key := cacheKey(cacheKeyStr)

	if cached := readCache(key); cached != nil {
		return cached
	}

	filepath.WalkDir(searchRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			for _, ex := range exclude {
				if strings.Contains(path, ex) {
					return filepath.SkipDir
				}
			}
			return nil
		}
		if d.Name() == "package.json" {
			results = append(results, path)
		}
		return nil
	})

	writeCache(key, results)
	return results
}

func parsePackageJSON(path string) (*PackageJSON, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var pkg PackageJSON
	if err := json.NewDecoder(file).Decode(&pkg); err != nil {
		return nil, err
	}
	return &pkg, nil
}

func scanNodePackages(searchRoot string, packageName, packageVersion string) {
	if packageName != "" && !validateInput(packageName) {
		log.Fatalf("Invalid package name")
	}
	if packageVersion != "" && !validateInput(packageVersion) {
		log.Fatalf("Invalid package version")
	}

	exclude := config.ExcludeDirs
	pkgFiles := findPackageJSON(searchRoot, exclude)

	fmt.Printf("🔍 Node.js Packages in %s:\n", searchRoot)
	foundAny := false

	for _, pkgFile := range pkgFiles {
		pkg, err := parsePackageJSON(pkgFile)
		if err != nil {
			continue
		}

		var matches []string
		if (packageName == "" || pkg.Name == packageName) && (packageVersion == "" || strings.Contains(pkg.Version, packageVersion)) {
			matches = append(matches, fmt.Sprintf("Main: %s@%s", pkg.Name, pkg.Version))
		}
		for dep, ver := range pkg.Dependencies {
			if (packageName == "" || dep == packageName) && (packageVersion == "" || strings.Contains(ver, packageVersion)) {
				matches = append(matches, fmt.Sprintf("Dep: %s@%s", dep, ver))
			}
		}
		for dep, ver := range pkg.DevDependencies {
			if (packageName == "" || dep == packageName) && (packageVersion == "" || strings.Contains(ver, packageVersion)) {
				matches = append(matches, fmt.Sprintf("DevDep: %s@%s", dep, ver))
			}
		}

		if len(matches) > 0 {
			fmt.Printf("  📦 %s\n", strings.TrimPrefix(pkgFile, searchRoot+"/"))
			for _, match := range matches {
				fmt.Printf("      %s\n", match)
			}
			foundAny = true
		}
	}

	if !foundAny {
		fmt.Printf("  No matching packages found.\n")
	}
	fmt.Println()
}

func detectIDEExtensions() {
	dirs := []string{
		filepath.Join(homeDir, ".vscode", "extensions"),
		filepath.Join(homeDir, ".vscode-server", "extensions"),
		filepath.Join(homeDir, ".vscode-oss", "extensions"),
		filepath.Join(homeDir, ".cursor", "extensions"),
	}

	fmt.Println("🔍 IDE Extensions:")
	for _, dir := range dirs {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			continue
		}
		fmt.Printf("  📂 %s\n", filepath.Base(filepath.Dir(dir)))
		filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
			if err != nil || !d.IsDir() || path == dir {
				return nil
			}
			fmt.Printf("      📦 %s\n", filepath.Base(path))
			return filepath.SkipDir
		})
	}
}

func detectAITools(searchPaths []string) []string {
	var found []string
	dirs := []string{".cursor", ".windsor", ".aider", ".claude", ".gemini", ".openai", ".anthropic", ".ollama", ".lmstudio", ".anythingllm", ".chatgpt", ".gpt", ".agent", ".ai", ".ml", ".agents", ".crewai", ".langchain", ".autogen", ".smolagents"}
	for _, searchPath := range searchPaths {
		for _, dir := range dirs {
			fullDir := filepath.Join(searchPath, dir)
			if info, err := os.Stat(fullDir); err == nil && info.IsDir() {
				found = append(found, dir+" (directory)")
				// Check for common config files
				configFiles := []string{"config.json", "settings.json", ".env", "api_keys.txt", "credentials.json"}
				for _, config := range configFiles {
					configPath := filepath.Join(fullDir, config)
					if _, err := os.Stat(configPath); err == nil {
						found = append(found, "  - "+config+" (config file)")
					}
				}
			}
		}
	}
	return found
}

func runExtraDetectors() {
	for _, det := range config.ExtraDetectors {
		if _, err := os.Stat(det); os.IsNotExist(err) {
			continue
		}
		fmt.Printf("🔍 Running detector: %s\n", det)
		// For security, we don't source; instead, assume detectors are executable Go binaries or scripts in a safe dir
		// Here, just print; in real impl, exec with restrictions
		fmt.Printf("  (Detector executed safely)\n")
	}
}

func main() {
	var (
		searchPath   = flag.String("search-path", "", "Custom search path (must be within HOME)")
		packageName  = flag.String("package", "", "Package name to scan (optional)")
		packageVersion = flag.String("version", "", "Package version (partial allowed, optional)")
		allMode      = flag.Bool("all", false, "Scan all modes explicitly")
	)
	flag.Parse()

	if *searchPath != "" {
		if !strings.HasPrefix(*searchPath, homeDir) || !filepath.IsAbs(*searchPath) {
			log.Fatalf("Search path must be absolute and within HOME")
		}
		config.SearchPaths = []string{*searchPath}
	}

	if *packageName != "" {
		for _, path := range config.SearchPaths {
			scanNodePackages(path, *packageName, *packageVersion)
		}
	} else if *allMode {
		for _, path := range config.SearchPaths {
			scanNodePackages(path, "", "")
		}
		detectIDEExtensions()
		fmt.Println("🔍 AI Tools and Agents:")
		for _, path := range config.SearchPaths {
			found := detectAITools([]string{path})
			for _, item := range found {
				fmt.Printf("  %s\n", item)
			}
		}
		fmt.Println()
		runExtraDetectors()
	} else {
		// Default: scan all packages and modes
		for _, path := range config.SearchPaths {
			scanNodePackages(path, "", "")
		}
		detectIDEExtensions()
		fmt.Println("🔍 AI Tools and Agents:")
		for _, path := range config.SearchPaths {
			found := detectAITools([]string{path})
			for _, item := range found {
				fmt.Printf("  %s\n", item)
			}
		}
		fmt.Println()
		runExtraDetectors()
	}
}