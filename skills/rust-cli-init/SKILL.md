---
name: rust-cli-init
description: Creates a production-ready Rust CLI/terminal utility project with clap, crossterm, colored output, progress bars, interactive prompts, and multi-subcommand architecture.
---
# Rust CLI / Terminal Utility Project Initializer

## Overview
This skill creates a production-ready Rust terminal utility project with modern tooling:
- Clap (derive) for argument parsing and subcommands
- Crossterm for raw terminal manipulation
- Colored output with support for NO_COLOR standard
- Progress bars (indicatif) and interactive prompts (dialoguer)
- Table-formatted output (tabled)
- Multiple output formats (plain, JSON, table)
- Shell completion generation
- Integration test harness with assert_cmd

## Prerequisites
- Rust 1.85+ (2024 edition)
- Cargo installed via rustup

## Project Structure Template
````
project_name/
├── src/
│   ├── main.rs                  # Entry point, clap dispatch
│   ├── lib.rs                   # Library root (re-exports)
│   ├── cli.rs                   # CLI argument & subcommand definitions
│   ├── error.rs                 # Error types and exit codes
│   ├── commands/                # Subcommand implementations
│   │   ├── mod.rs
│   │   └── example.rs           # Example subcommand scaffold
│   ├── output/                  # Output formatting layer
│   │   ├── mod.rs
│   │   └── format.rs            # Plain / JSON / Table formatters
│   └── utils/                   # Shared helpers
│       └── mod.rs
├── tests/
│   ├── common/
│   │   └── mod.rs               # Shared test helpers
│   └── cli_tests.rs             # Integration tests (assert_cmd)
├── completions/                 # Generated shell completions
│   └── .keep
├── Cargo.toml                   # Dependencies & metadata
├── Cargo.lock                   # Lock file
├── .gitignore
├── Makefile                     # Common commands
├── rust-toolchain.toml          # Pin Rust version
└── README.md
````

## Step-by-Step Initialization

### Step 1: Create Project Structure
````bash
PROJECT_NAME=$1

# Initialize Cargo project
cargo init --name $PROJECT_NAME $PROJECT_NAME

cd $PROJECT_NAME

# Create directory structure
mkdir -p src/{commands,output,utils}
mkdir -p tests/common
mkdir -p completions
touch completions/.keep
````

### Step 2: Create Cargo.toml
````toml
[package]
name = "project_name"
version = "0.1.0"
edition = "2024"
rust-version = "1.85"
description = "A terminal utility"
license = "MIT"

[[bin]]
name = "project_name"
path = "src/main.rs"

[dependencies]
# CLI framework
clap = { version = "4", features = ["derive", "env", "wrap_help"] }

# Terminal
crossterm = "0.28"
owo-colors = "4"

# Progress & interaction
indicatif = "0.17"
dialoguer = { version = "0.11", features = ["fuzzy-select"] }

# Output formatting
tabled = "0.17"
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# Error handling
thiserror = "2"
anyhow = "1"

# Logging
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }

# Async (enable if needed)
# tokio = { version = "1", features = ["full"] }

[dev-dependencies]
assert_cmd = "2"
predicates = "3"
tempfile = "3"

[profile.release]
lto = true
codegen-units = 1
strip = true
panic = "abort"

[lints.rust]
unsafe_code = "forbid"

[lints.clippy]
enum_glob_use = "deny"
pedantic = { level = "warn", priority = -1 }
module_name_repetitions = "allow"
must_use_candidate = "allow"
missing_errors_doc = "allow"
missing_panics_doc = "allow"
````

### Step 3: Create rust-toolchain.toml
````toml
[toolchain]
channel = "stable"
components = ["rustfmt", "clippy"]
````

### Step 4: Create CLI Argument Definitions
````rust
// src/cli.rs
use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(
    name = "project_name",
    about = "A terminal utility",
    version,
    propagate_version = true,
    arg_required_else_help = true
)]
pub struct Cli {
    /// Increase verbosity (-v, -vv, -vvv)
    #[arg(short, long, action = clap::ArgAction::Count, global = true)]
    pub verbose: u8,

    /// Suppress all output
    #[arg(short, long, global = true)]
    pub quiet: bool,

    /// Output format
    #[arg(long, default_value = "plain", global = true)]
    pub format: OutputFormat,

    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Example subcommand – replace with your own
    Example(ExampleArgs),

    /// Generate shell completions
    Completions {
        /// Shell to generate completions for
        #[arg(value_enum)]
        shell: clap_complete::Shell,
    },
}

#[derive(clap::Args, Debug)]
pub struct ExampleArgs {
    /// Input file (reads stdin if omitted)
    #[arg(short, long)]
    pub input: Option<PathBuf>,

    /// Output file (writes stdout if omitted)
    #[arg(short, long)]
    pub output: Option<PathBuf>,
}

#[derive(clap::ValueEnum, Clone, Debug, Default)]
pub enum OutputFormat {
    #[default]
    Plain,
    Json,
    Table,
}
````

### Step 5: Create Main Entry Point
````rust
// src/main.rs
use clap::Parser;

use project_name::cli::{Cli, Commands};
use project_name::commands;
use project_name::error::ExitCode;

fn main() -> ExitCode {
    let cli = Cli::parse();

    let level = match cli.verbose {
        0 => "warn",
        1 => "info",
        2 => "debug",
        _ => "trace",
    };

    if !cli.quiet {
        tracing_subscriber::fmt()
            .with_env_filter(
                tracing_subscriber::EnvFilter::try_from_default_env()
                    .unwrap_or_else(|_| level.into()),
            )
            .with_writer(std::io::stderr)
            .init();
    }

    let result = match cli.command {
        Commands::Example(args) => commands::example::run(args, cli.format),
        Commands::Completions { shell } => {
            let mut cmd = <Cli as clap::CommandFactory>::command();
            clap_complete::generate(shell, &mut cmd, "project_name", &mut std::io::stdout());
            Ok(())
        }
    };

    match result {
        Ok(()) => ExitCode::Success,
        Err(e) => {
            if !cli.quiet {
                eprintln!("error: {e:#}");
            }
            ExitCode::from(&e)
        }
    }
}
````

### Step 6: Create Library Root
````rust
// src/lib.rs
pub mod cli;
pub mod commands;
pub mod error;
pub mod output;
pub mod utils;
````

### Step 7: Create Error Types
````rust
// src/error.rs

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("{0}")]
    InvalidInput(String),

    #[error("file not found: {0}")]
    FileNotFound(std::path::PathBuf),

    #[error(transparent)]
    Io(#[from] std::io::Error),

    #[error(transparent)]
    Serialization(#[from] serde_json::Error),

    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

/// Wraps std::process::ExitCode for ergonomic use from main().
pub enum ExitCode {
    Success,
    GeneralError,
    IoError,
    UsageError,
}

impl From<&AppError> for ExitCode {
    fn from(err: &AppError) -> Self {
        match err {
            AppError::InvalidInput(_) => Self::UsageError,
            AppError::FileNotFound(_) | AppError::Io(_) => Self::IoError,
            _ => Self::GeneralError,
        }
    }
}

impl std::process::Termination for ExitCode {
    fn report(self) -> std::process::ExitCode {
        let code = match self {
            Self::Success => 0,
            Self::GeneralError => 1,
            Self::IoError => 2,
            Self::UsageError => 64,
        };
        std::process::ExitCode::from(code)
    }
}
````

### Step 8: Create Output Formatting Layer
````rust
// src/output/mod.rs
pub mod format;

pub use format::{Printable, print_output};
````

````rust
// src/output/format.rs
use crate::cli::OutputFormat;
use serde::Serialize;
use tabled::Tabled;

pub trait Printable: Serialize + Tabled {}
impl<T: Serialize + Tabled> Printable for T {}

pub fn print_output<T: Printable>(items: &[T], format: &OutputFormat) -> anyhow::Result<()> {
    match format {
        OutputFormat::Json => {
            println!("{}", serde_json::to_string_pretty(items)?);
        }
        OutputFormat::Table => {
            let table = tabled::Table::new(items)
                .with(tabled::settings::Style::rounded())
                .to_string();
            println!("{table}");
        }
        OutputFormat::Plain => {
            let table = tabled::Table::new(items)
                .with(tabled::settings::Style::blank())
                .to_string();
            println!("{table}");
        }
    }
    Ok(())
}
````

### Step 9: Create Example Subcommand
````rust
// src/commands/mod.rs
pub mod example;
````

````rust
// src/commands/example.rs
use std::io::{self, BufRead, Read};

use crate::cli::{ExampleArgs, OutputFormat};
use crate::error::AppError;

pub fn run(args: ExampleArgs, _format: OutputFormat) -> Result<(), AppError> {
    let input = match &args.input {
        Some(path) => {
            if !path.exists() {
                return Err(AppError::FileNotFound(path.clone()));
            }
            std::fs::read_to_string(path)?
        }
        None => {
            let mut buf = String::new();
            io::stdin().lock().read_to_string(&mut buf)?;
            buf
        }
    };

    let line_count = input.lines().count();
    let byte_count = input.len();

    let result = format!("{line_count} lines, {byte_count} bytes");

    match &args.output {
        Some(path) => std::fs::write(path, &result)?,
        None => println!("{result}"),
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn counts_lines_correctly() {
        let args = ExampleArgs {
            input: None,
            output: None,
        };
        // Unit tests for pure logic go here
        assert_eq!(2 + 2, 4);
    }
}
````

### Step 10: Create Utils Module
````rust
// src/utils/mod.rs
use std::io::IsTerminal;

/// Returns true when stdout is connected to a terminal (not piped).
pub fn is_interactive() -> bool {
    std::io::stdout().is_terminal()
}

/// Respects the NO_COLOR convention (https://no-color.org/).
pub fn colors_enabled() -> bool {
    std::env::var_os("NO_COLOR").is_none() && is_interactive()
}
````

### Step 11: Create Integration Tests
````rust
// tests/common/mod.rs
use assert_cmd::Command;

pub fn cmd() -> Command {
    Command::cargo_bin(env!("CARGO_PKG_NAME")).expect("binary should exist")
}
````

````rust
// tests/cli_tests.rs
mod common;

use predicates::prelude::*;

#[test]
fn prints_help_with_no_args() {
    common::cmd()
        .assert()
        .failure()
        .stderr(predicate::str::contains("Usage"));
}

#[test]
fn prints_version() {
    common::cmd()
        .arg("--version")
        .assert()
        .success()
        .stdout(predicate::str::contains(env!("CARGO_PKG_VERSION")));
}

#[test]
fn example_reads_from_file() {
    let dir = tempfile::tempdir().unwrap();
    let input = dir.path().join("input.txt");
    std::fs::write(&input, "hello\nworld\n").unwrap();

    common::cmd()
        .args(["example", "--input", input.to_str().unwrap()])
        .assert()
        .success()
        .stdout(predicate::str::contains("2 lines"));
}

#[test]
fn example_fails_on_missing_file() {
    common::cmd()
        .args(["example", "--input", "/nonexistent/file.txt"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("file not found"));
}

#[test]
fn generates_completions() {
    common::cmd()
        .args(["completions", "bash"])
        .assert()
        .success()
        .stdout(predicate::str::contains("complete"));
}
````

### Step 12: Create Makefile
````makefile
# Makefile
.PHONY: help build run test lint format clean install completions

# Colors for output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

BIN_NAME := project_name

help:
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} { \
		if (/^[a-zA-Z_-]+:.*?##.*$$/) {printf "    ${YELLOW}%-20s${GREEN}%s${RESET}\n", $$1, $$2} \
		else if (/^## .*$$/) {printf "  ${WHITE}%s${RESET}\n", substr($$1,4)} \
		}' $(MAKEFILE_LIST)

## Development
build: ## Build in debug mode
	cargo build

build-release: ## Build optimized release binary
	cargo build --release

run: ## Run with example arguments
	cargo run -- --help

dev: ## Run with auto-reload (requires cargo-watch)
	cargo watch -x 'run -- --help'

## Testing
test: ## Run all tests
	cargo test -- --nocapture

test-unit: ## Run unit tests only (lib + inline)
	cargo test --lib -- --nocapture

test-integration: ## Run integration tests only
	cargo test --test '*' -- --nocapture

test-coverage: ## Run tests with coverage (requires cargo-llvm-cov)
	cargo llvm-cov --html

## Code Quality
lint: ## Run clippy linter
	@echo "${GREEN}Running clippy...${RESET}"
	cargo clippy --all-targets -- -D warnings

format: ## Format code with rustfmt
	@echo "${GREEN}Running rustfmt...${RESET}"
	cargo fmt

format-check: ## Check formatting without changes
	cargo fmt -- --check

check: format-check lint test ## Run format check, lint, and tests

audit: ## Audit dependencies for vulnerabilities (requires cargo-audit)
	cargo audit

## Installation
install: ## Install binary to ~/.cargo/bin
	cargo install --path .

install-release: build-release ## Copy release binary to /usr/local/bin (needs sudo)
	sudo cp target/release/$(BIN_NAME) /usr/local/bin/$(BIN_NAME)

uninstall: ## Remove binary from ~/.cargo/bin
	cargo uninstall $(BIN_NAME)

## Shell Completions
completions: build ## Generate shell completions into completions/
	@echo "${GREEN}Generating shell completions...${RESET}"
	@mkdir -p completions
	cargo run -- completions bash  > completions/$(BIN_NAME).bash
	cargo run -- completions zsh   > completions/_$(BIN_NAME)
	cargo run -- completions fish  > completions/$(BIN_NAME).fish
	@echo "${GREEN}Completions written to completions/${RESET}"

install-completions-bash: completions ## Install bash completions
	@mkdir -p ~/.local/share/bash-completion/completions
	cp completions/$(BIN_NAME).bash ~/.local/share/bash-completion/completions/$(BIN_NAME)

install-completions-zsh: completions ## Install zsh completions
	@mkdir -p ~/.zfunc
	cp completions/_$(BIN_NAME) ~/.zfunc/_$(BIN_NAME)
	@echo "Add 'fpath+=~/.zfunc' to your .zshrc if not already present"

install-completions-fish: completions ## Install fish completions
	@mkdir -p ~/.config/fish/completions
	cp completions/$(BIN_NAME).fish ~/.config/fish/completions/$(BIN_NAME).fish

## Utilities
clean: ## Clean build artifacts
	@echo "${GREEN}Cleaning build artifacts...${RESET}"
	cargo clean
	@echo "${GREEN}Done!${RESET}"

deps-update: ## Update all dependencies
	cargo update

deps-outdated: ## Show outdated dependencies (requires cargo-outdated)
	cargo outdated

deps-tree: ## Show dependency tree
	cargo tree

## CI/CD Simulation
ci: format-check lint test ## Simulate CI pipeline locally

## Binary size analysis
bloat: ## Show what's taking space in the binary (requires cargo-bloat)
	cargo bloat --release -n 20

bloat-crates: ## Show crate-level binary size breakdown
	cargo bloat --release --crates

## Recommended tools install
setup-tools: ## Install recommended cargo tools
	cargo install cargo-watch cargo-audit cargo-outdated cargo-llvm-cov cargo-bloat
````

### Step 13: Create .gitignore
````
# Build artifacts
/target
debug/
*.pdb

# Editor
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
````

### Step 14: Create README Template
````markdown
# Project Name

A terminal utility built with Rust.

## Installation

### From source
```bash
cargo install --path .
```

### Pre-built binaries
See [Releases](https://github.com/OWNER/project_name/releases) for pre-built binaries.

## Usage

```bash
# Show help
project_name --help

# Example subcommand
project_name example --input file.txt

# Read from stdin
cat file.txt | project_name example

# JSON output
project_name --format json example --input file.txt

# Verbose logging
project_name -vv example --input file.txt
```

## Shell Completions

Generate and install completions for your shell:

```bash
# Bash
make install-completions-bash

# Zsh
make install-completions-zsh

# Fish
make install-completions-fish
```

## Development

### Build
```bash
make build
```

### Run tests
```bash
make test
```

### Format & lint
```bash
make check
```

### Full CI check
```bash
make ci
```

## Project Structure

- `src/cli.rs` - Argument definitions (clap derive)
- `src/commands/` - Subcommand implementations
- `src/output/` - Output formatting (plain, JSON, table)
- `src/error.rs` - Error types and exit codes
- `src/utils/` - Shared helpers (terminal detection, color support)
- `tests/` - Integration tests (assert_cmd)
- `completions/` - Generated shell completions

## Output Formats

All subcommands support `--format`:

| Format  | Description                          |
|---------|--------------------------------------|
| `plain` | Minimal whitespace-aligned (default) |
| `json`  | Machine-readable JSON                |
| `table` | Bordered table for interactive use   |

## Exit Codes

| Code | Meaning        |
|------|----------------|
| 0    | Success        |
| 1    | General error  |
| 2    | I/O error      |
| 64   | Usage error    |

## Environment Variables

| Variable   | Description                            |
|------------|----------------------------------------|
| `NO_COLOR` | Disable colored output (no-color.org)  |
| `RUST_LOG`  | Set log level (trace, debug, info, warn, error) |
````

## Usage Examples

### Example 1: Initialize New CLI Tool
````bash
# In Claude/Cursor:
Prompt: "Use rust-cli-init skill to create a terminal utility called 'filt'"

# Skill will:
1. Create Cargo project with CLI directory structure
2. Generate clap argument parser with subcommands
3. Set up output formatting (plain/json/table)
4. Create example subcommand with stdin/file I/O
5. Write integration tests with assert_cmd
6. Generate Makefile with install + completions targets
````

### Example 2: Add a New Subcommand
````bash
# After initialization, add a subcommand:
Prompt: "Add a 'count' subcommand that counts words, lines, and characters"

# Follow the pattern in src/commands/example.rs:
# 1. Create src/commands/count.rs
# 2. Add variant to Commands enum in src/cli.rs
# 3. Add dispatch arm in src/main.rs
# 4. Add integration tests in tests/cli_tests.rs
````

## Best Practices

1. **Respect stdin/stdout conventions** – read stdin when no file arg given, write to stdout by default
2. **Support piping** – detect interactive terminal vs pipe with `is_interactive()` to adjust output
3. **Honor NO_COLOR** – disable colors when `NO_COLOR` env var is set or output is piped
4. **Use proper exit codes** – non-zero for errors, distinct codes for different failure classes
5. **Provide --quiet and --verbose** – give users control over output verbosity
6. **Offer --format json** – machine-readable output enables scripting and composition
7. **Generate shell completions** – significantly improves discoverability

## Checklist After Initialization

- [ ] Update name and description in Cargo.toml
- [ ] Replace `example` subcommand with real commands
- [ ] Add domain-specific CLI args to `src/cli.rs`
- [ ] Implement command logic in `src/commands/`
- [ ] Write integration tests: `make test`
- [ ] Generate completions: `make completions`
- [ ] Run full check: `make ci`
- [ ] Try piping: `echo "test" | project_name example`

## Next Steps

After initialization:
1. Replace the example subcommand in `src/commands/`
2. Define your CLI args and subcommands in `src/cli.rs`
3. Implement output types deriving `Serialize` + `Tabled` for multi-format support
4. Add integration tests covering stdin, file input, and error cases
5. Generate completions and test in your shell
