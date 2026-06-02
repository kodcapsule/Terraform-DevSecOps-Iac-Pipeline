#!/usr/bin/env bash
# =============================================================================
# setup-pre-commit.sh
# Enterprise Pre-Commit Framework — Terraform DevSecOps Pipeline
#
# Installs and configures all pre-commit hooks across 3 security layers:
#   Layer 1 — Code Quality & IaC Security
#             (terraform_fmt, terraform_validate, terraform_tflint,
#              terraform_trivy, terraform_checkov, terrascan)
#   Layer 2 — Secret Detection
#             (gitleaks, detect-secrets)
#   Layer 3 — File Hygiene
#             (trailing-whitespace, check-yaml, check-json,
#              check-added-large-files)
#
# Supported OS: Ubuntu/Debian, macOS (Homebrew)
# Usage:
#   chmod +x setup-pre-commit.sh
#   ./setup-pre-commit.sh              # install + configure in current repo
#   ./setup-pre-commit.sh --dry-run    # show what would be done, no changes
#   ./setup-pre-commit.sh --ci         # CI mode: skip interactive prompts
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# CONSTANTS & DEFAULTS
# -----------------------------------------------------------------------------
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly LOG_FILE="/tmp/setup-pre-commit-$(date +%Y%m%d-%H%M%S).log"

readonly PRE_COMMIT_CONFIG=".pre-commit-config.yaml"
readonly DETECT_SECRETS_BASELINE=".secrets.baseline"
readonly GITLEAKS_CONFIG=".gitleaks.toml"

# Tool version pins — update these to bump dependencies
readonly PRECOMMIT_HOOKS_VERSION="v4.6.0"
readonly TERRAFORM_HOOKS_VERSION="v1.96.1"
readonly GITLEAKS_VERSION="v8.18.4"
readonly DETECT_SECRETS_VERSION="1.5.0"
readonly TFLINT_VERSION="v0.51.1"
readonly TRIVY_VERSION="v0.52.2"
readonly CHECKOV_VERSION="3.2.101"
readonly TERRASCAN_VERSION="v1.19.1"

# Colours (disabled automatically in CI / non-TTY)
if [[ -t 1 ]] && [[ "${CI:-false}" != "true" ]]; then
  RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; YELLOW=''; GREEN=''; CYAN=''; BOLD=''; DIM=''; RESET=''
fi

# Flags
DRY_RUN=false
CI_MODE=false
SKIP_CONFIRM=false

# -----------------------------------------------------------------------------
# HELPERS
# -----------------------------------------------------------------------------
log()       { echo -e "${DIM}[$(date +%H:%M:%S)]${RESET} $*" | tee -a "$LOG_FILE"; }
info()      { echo -e "${CYAN}  ℹ  $*${RESET}"  | tee -a "$LOG_FILE"; }
success()   { echo -e "${GREEN}  ✔  $*${RESET}"  | tee -a "$LOG_FILE"; }
warn()      { echo -e "${YELLOW}  ⚠  $*${RESET}" | tee -a "$LOG_FILE"; }
error()     { echo -e "${RED}  ✖  $*${RESET}" >&2 | tee -a "$LOG_FILE"; }
step()      { echo -e "\n${BOLD}${CYAN}──── $* ${RESET}" | tee -a "$LOG_FILE"; }
separator() { echo -e "${DIM}$(printf '─%.0s' {1..70})${RESET}" | tee -a "$LOG_FILE"; }

die() {
  error "$*"
  echo -e "${DIM}  Log: $LOG_FILE${RESET}"
  exit 1
}

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${DIM}  [dry-run] $*${RESET}"
  else
    log "Running: $*"
    eval "$@" >> "$LOG_FILE" 2>&1 || die "Command failed: $*"
  fi
}

command_exists() { command -v "$1" &>/dev/null; }

confirm() {
  [[ "$CI_MODE" == "true" || "$SKIP_CONFIRM" == "true" ]] && return 0
  read -rp "$(echo -e "${YELLOW}  ?  $* [y/N]: ${RESET}")" ans
  [[ "${ans:-n}" =~ ^[Yy]$ ]]
}

# -----------------------------------------------------------------------------
# ARGUMENT PARSING
# -----------------------------------------------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)    DRY_RUN=true;      shift ;;
      --ci)         CI_MODE=true;      SKIP_CONFIRM=true; shift ;;
      --yes|-y)     SKIP_CONFIRM=true; shift ;;
      --help|-h)    usage;             exit 0 ;;
      *)            die "Unknown argument: $1. Run with --help for usage." ;;
    esac
  done
}

usage() {
  cat <<EOF

${BOLD}${SCRIPT_NAME} v${SCRIPT_VERSION}${RESET}
Enterprise pre-commit setup for Terraform DevSecOps pipelines.

${BOLD}Usage:${RESET}
  ./${SCRIPT_NAME} [options]

${BOLD}Options:${RESET}
  --dry-run    Show what would be done without making changes
  --ci         Non-interactive mode for CI pipelines
  --yes, -y    Skip all confirmation prompts
  --help, -h   Show this help message

${BOLD}What this script does:${RESET}
  1. Detects and validates OS (Ubuntu/Debian or macOS)
  2. Installs system dependencies (Python, pip, curl, git)
  3. Installs pre-commit framework
  4. Installs Layer 1 tools: tflint, Trivy, Checkov, Terrascan
  5. Installs Layer 2 tools: Gitleaks, detect-secrets
  6. Generates .pre-commit-config.yaml with all 3 security layers
  7. Generates .gitleaks.toml configuration
  8. Initialises detect-secrets baseline
  9. Installs git hooks into the current repository
  10. Runs a full pre-commit baseline run

EOF
}

# -----------------------------------------------------------------------------
# SYSTEM DETECTION
# -----------------------------------------------------------------------------
detect_os() {
  step "Detecting operating system"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    if ! command_exists brew; then
      die "Homebrew is required on macOS. Install from https://brew.sh"
    fi
    success "macOS detected — Homebrew available"
  elif [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    case "$ID" in
      ubuntu|debian|linuxmint|pop)
        OS="debian"
        success "Debian-based Linux detected: $PRETTY_NAME"
        ;;
      rhel|centos|fedora|amzn)
        die "RHEL/CentOS/Fedora detected. This script supports Ubuntu/Debian and macOS. Adapt the package manager calls for yum/dnf."
        ;;
      *)
        warn "Unrecognised distro: $ID. Attempting Debian-style install (may fail)."
        OS="debian"
        ;;
    esac
  else
    die "Cannot detect OS. Supported: Ubuntu/Debian, macOS."
  fi
}

# -----------------------------------------------------------------------------
# PREREQUISITE CHECK
# -----------------------------------------------------------------------------
check_prerequisites() {
  step "Checking prerequisites"

  local missing=()

  # Git must already exist — we're installing into a repo
  command_exists git || missing+=("git")

  # Python 3.8+ required for pre-commit and detect-secrets
  if command_exists python3; then
    local py_version
    py_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    local py_major py_minor
    py_major=$(echo "$py_version" | cut -d. -f1)
    py_minor=$(echo "$py_version" | cut -d. -f2)
    if [[ "$py_major" -lt 3 ]] || { [[ "$py_major" -eq 3 ]] && [[ "$py_minor" -lt 8 ]]; }; then
      die "Python 3.8+ required (found $py_version). Please upgrade Python."
    fi
    success "Python $py_version found"
  else
    missing+=("python3")
  fi

  # Must be inside a git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    die "Not inside a git repository. Run 'git init' first, or cd into your project root."
  fi
  success "Git repository confirmed: $(git rev-parse --show-toplevel)"

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "Missing prerequisites: ${missing[*]}"
    info "These will be installed in the next step."
  else
    success "All prerequisites satisfied"
  fi
}

# -----------------------------------------------------------------------------
# SYSTEM DEPENDENCIES
# -----------------------------------------------------------------------------
install_system_deps() {
  step "Installing system dependencies"

  if [[ "$OS" == "debian" ]]; then
    info "Updating apt cache..."
    run "sudo apt-get update -qq"
    run "sudo apt-get install -y -qq curl wget unzip git python3 python3-pip python3-venv jq"

  elif [[ "$OS" == "macos" ]]; then
    info "Installing via Homebrew..."
    run "brew install curl wget git python3 jq || brew upgrade curl wget git python3 jq"
  fi

  success "System dependencies installed"
}

# -----------------------------------------------------------------------------
# LAYER 0: PRE-COMMIT FRAMEWORK
# -----------------------------------------------------------------------------
install_precommit() {
  step "Layer 0 — Installing pre-commit framework"

  if command_exists pre-commit; then
    local current_version
    current_version=$(pre-commit --version 2>&1 | awk '{print $2}')
    info "pre-commit already installed: v${current_version}"
    if confirm "Re-install / upgrade pre-commit?"; then
      run "pip3 install --upgrade --quiet pre-commit"
    fi
  else
    info "Installing pre-commit via pip..."
    run "pip3 install --quiet pre-commit"
  fi

  command_exists pre-commit || die "pre-commit installation failed."
  success "pre-commit $(pre-commit --version | awk '{print $2}') ready"
}

# -----------------------------------------------------------------------------
# LAYER 1: CODE QUALITY & IaC SECURITY TOOLS
# -----------------------------------------------------------------------------
install_terraform_tools() {
  step "Layer 1 — Installing IaC security tools"

  # ── tflint ──────────────────────────────────────────────────────────────────
  if command_exists tflint; then
    success "tflint already installed: $(tflint --version | head -1)"
  else
    info "Installing tflint ${TFLINT_VERSION}..."
    if [[ "$OS" == "macos" ]]; then
      run "brew install tflint"
    else
      local tflint_url="https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_amd64.zip"
      run "curl -sSL '$tflint_url' -o /tmp/tflint.zip"
      run "unzip -q /tmp/tflint.zip -d /tmp/tflint-bin"
      run "sudo mv /tmp/tflint-bin/tflint /usr/local/bin/tflint"
      run "sudo chmod +x /usr/local/bin/tflint"
      run "rm -rf /tmp/tflint.zip /tmp/tflint-bin"
    fi
    success "tflint installed"
  fi

  # ── Trivy ────────────────────────────────────────────────────────────────────
  if command_exists trivy; then
    success "trivy already installed: $(trivy --version | head -1)"
  else
    info "Installing Trivy ${TRIVY_VERSION}..."
    if [[ "$OS" == "macos" ]]; then
      run "brew install aquasecurity/trivy/trivy"
    else
      local trivy_url="https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/trivy_$(echo ${TRIVY_VERSION} | tr -d v)_Linux-64bit.deb"
      run "curl -sSL '$trivy_url' -o /tmp/trivy.deb"
      run "sudo dpkg -i /tmp/trivy.deb"
      run "rm -f /tmp/trivy.deb"
    fi
    success "trivy installed"
  fi

  # ── Checkov ──────────────────────────────────────────────────────────────────
  if command_exists checkov; then
    success "checkov already installed: $(checkov --version 2>&1 | head -1)"
  else
    info "Installing Checkov ${CHECKOV_VERSION}..."
    run "pip3 install --quiet checkov==${CHECKOV_VERSION}"
    success "checkov installed"
  fi

  # ── Terrascan ────────────────────────────────────────────────────────────────
  if command_exists terrascan; then
    success "terrascan already installed: $(terrascan version 2>&1 | head -1)"
  else
    info "Installing Terrascan ${TERRASCAN_VERSION}..."
    if [[ "$OS" == "macos" ]]; then
      run "brew install terrascan"
    else
      local terrascan_url="https://github.com/tenable/terrascan/releases/download/${TERRASCAN_VERSION}/terrascan_$(echo ${TERRASCAN_VERSION} | tr -d v)_Linux_x86_64.tar.gz"
      run "curl -sSL '$terrascan_url' -o /tmp/terrascan.tar.gz"
      run "tar -xzf /tmp/terrascan.tar.gz -C /tmp terrascan"
      run "sudo mv /tmp/terrascan /usr/local/bin/terrascan"
      run "sudo chmod +x /usr/local/bin/terrascan"
      run "rm -f /tmp/terrascan.tar.gz"
      # Initialise Terrascan policy engine
      run "terrascan init"
    fi
    success "terrascan installed"
  fi

  success "Layer 1 tools ready"
}

# -----------------------------------------------------------------------------
# LAYER 2: SECRET DETECTION TOOLS
# -----------------------------------------------------------------------------
install_secret_tools() {
  step "Layer 2 — Installing secret detection tools"

  # ── Gitleaks ─────────────────────────────────────────────────────────────────
  if command_exists gitleaks; then
    success "gitleaks already installed: $(gitleaks version 2>&1)"
  else
    info "Installing Gitleaks ${GITLEAKS_VERSION}..."
    if [[ "$OS" == "macos" ]]; then
      run "brew install gitleaks"
    else
      local gl_url="https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/gitleaks_$(echo ${GITLEAKS_VERSION} | tr -d v)_linux_x64.tar.gz"
      run "curl -sSL '$gl_url' -o /tmp/gitleaks.tar.gz"
      run "tar -xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks"
      run "sudo mv /tmp/gitleaks /usr/local/bin/gitleaks"
      run "sudo chmod +x /usr/local/bin/gitleaks"
      run "rm -f /tmp/gitleaks.tar.gz"
    fi
    success "gitleaks installed"
  fi

  # ── detect-secrets ───────────────────────────────────────────────────────────
  if command_exists detect-secrets; then
    success "detect-secrets already installed: $(detect-secrets --version 2>&1)"
  else
    info "Installing detect-secrets ${DETECT_SECRETS_VERSION}..."
    run "pip3 install --quiet detect-secrets==${DETECT_SECRETS_VERSION}"
    success "detect-secrets installed"
  fi

  success "Layer 2 tools ready"
}

# -----------------------------------------------------------------------------
# GENERATE .pre-commit-config.yaml
# -----------------------------------------------------------------------------
generate_precommit_config() {
  step "Generating ${PRE_COMMIT_CONFIG}"

  if [[ -f "$PRE_COMMIT_CONFIG" ]]; then
    warn "Existing ${PRE_COMMIT_CONFIG} found."
    if ! confirm "Overwrite it? (a backup will be created)"; then
      info "Skipping config generation — keeping existing file."
      return 0
    fi
    run "cp '${PRE_COMMIT_CONFIG}' '${PRE_COMMIT_CONFIG}.bak.$(date +%Y%m%d%H%M%S)'"
    info "Backup created."
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] Would write ${PRE_COMMIT_CONFIG}"
    return 0
  fi

  cat > "$PRE_COMMIT_CONFIG" <<YAML
# =============================================================================
# .pre-commit-config.yaml
# Enterprise Terraform DevSecOps — Pre-Commit Hook Configuration
#
# Layers:
#   1 — Code Quality & IaC Security  (terraform_fmt → terrascan)
#   2 — Secret Detection              (gitleaks, detect-secrets)
#   3 — File Hygiene                  (whitespace, yaml, json, large files)
#
# Install:  pre-commit install
# Run all:  pre-commit run --all-files
# Update:   pre-commit autoupdate
# =============================================================================

# Minimum pre-commit version required
minimum_pre_commit_version: "3.0.0"

# Default stages — run on commit and push
default_stages: [commit, push]

# Fail fast: stop after first failing hook in a stage
fail_fast: false

repos:

  # ===========================================================================
  # LAYER 1 — CODE QUALITY & IaC SECURITY
  # ===========================================================================

  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: ${TERRAFORM_HOOKS_VERSION}
    hooks:

      # ── terraform_fmt ──────────────────────────────────────────────────────
      # Rewrites all Terraform files to canonical format.
      # Fails if any file requires reformatting (enforces consistent style).
      - id: terraform_fmt
        name: "L1 · terraform fmt"
        args:
          - --args=-recursive
          - --args=-diff
        stages: [commit]

      # ── terraform_validate ─────────────────────────────────────────────────
      # Validates Terraform configuration syntax and internal consistency.
      # Runs per-directory; skips directories without a .terraform/ init.
      - id: terraform_validate
        name: "L1 · terraform validate"
        args:
          - --init-flags=-upgrade
        stages: [commit]

      # ── terraform_tflint ───────────────────────────────────────────────────
      # AWS-provider linting: deprecated resources, naming conventions,
      # invalid argument values, and unused variables.
      - id: terraform_tflint
        name: "L1 · tflint"
        args:
          - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl
          - --args=--enable-plugin=aws
          - --args=--minimum-failure-severity=warning
        stages: [commit]

      # ── terraform_trivy ────────────────────────────────────────────────────
      # Scans Terraform IaC for misconfigurations (CIS benchmarks, NIST,
      # AWS best practices). Also scans module dependencies for CVEs.
      - id: terraform_trivy
        name: "L1 · trivy (IaC + modules)"
        args:
          - --args=--severity=HIGH,CRITICAL
          - --args=--exit-code=1
          - --args=--ignorefile=__GIT_WORKING_DIR__/.trivyignore
        stages: [commit, push]

      # ── terraform_checkov ──────────────────────────────────────────────────
      # Deep static analysis: 1000+ checks across CIS, SOC2, HIPAA, GDPR,
      # PCI-DSS frameworks. Outputs SARIF for GitHub Security tab upload.
      - id: terraform_checkov
        name: "L1 · checkov (policy compliance)"
        args:
          - --args=--config-file=__GIT_WORKING_DIR__/.checkov.yaml
          - --args=--framework=terraform
          - --args=--output=cli
          - --args=--compact
          - --args=--quiet
        stages: [push]

      # ── terrascan ──────────────────────────────────────────────────────────
      # Policy-as-Code engine with 500+ policies. Complements Checkov
      # with Tenable's rule set and OPA-based custom policy support.
      - id: terraform_terrascan
        name: "L1 · terrascan (policy engine)"
        args:
          - --args=--iac-type=terraform
          - --args=--severity=HIGH
          - --args=--non-recursive
        stages: [push]

  # ===========================================================================
  # LAYER 2 — SECRET DETECTION
  # ===========================================================================

  - repo: https://github.com/gitleaks/gitleaks
    rev: ${GITLEAKS_VERSION}
    hooks:

      # ── gitleaks ───────────────────────────────────────────────────────────
      # Scans staged changes (commit) and the full diff (push) for hardcoded
      # secrets: API keys, tokens, passwords, private keys, AWS credentials.
      # Config: .gitleaks.toml (custom rules + false-positive allowlist).
      - id: gitleaks
        name: "L2 · gitleaks (secrets scan)"
        args:
          - --config=.gitleaks.toml
          - --verbose
          - --redact
        stages: [commit, push]

  - repo: https://github.com/Yelp/detect-secrets
    rev: v${DETECT_SECRETS_VERSION}
    hooks:

      # ── detect-secrets ─────────────────────────────────────────────────────
      # Entropy-based secret scanner. Works alongside Gitleaks — uses
      # different detection algorithms to catch what Gitleaks may miss.
      # Baseline file (.secrets.baseline) tracks known/approved findings.
      - id: detect-secrets
        name: "L2 · detect-secrets (entropy scan)"
        args:
          - --baseline
          - .secrets.baseline
          - --exclude-files
          - \.terraform/.*
          - --exclude-files
          - \.tfstate.*
        stages: [commit]

  # ===========================================================================
  # LAYER 3 — FILE HYGIENE
  # ===========================================================================

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: ${PRECOMMIT_HOOKS_VERSION}
    hooks:

      # ── trailing-whitespace ────────────────────────────────────────────────
      - id: trailing-whitespace
        name: "L3 · trailing whitespace"
        args: [--markdown-linebreak-ext=md]
        stages: [commit]

      # ── check-yaml ─────────────────────────────────────────────────────────
      # Validates YAML syntax across all .yml and .yaml files.
      # Multi-document YAML (e.g. K8s manifests) is supported via unsafe=true.
      - id: check-yaml
        name: "L3 · check yaml syntax"
        args: [--unsafe]
        stages: [commit]

      # ── check-json ─────────────────────────────────────────────────────────
      # Validates JSON syntax — catches malformed policy documents,
      # Terraform JSON configs, and GitHub Actions output files.
      - id: check-json
        name: "L3 · check json syntax"
        stages: [commit]

      # ── check-added-large-files ────────────────────────────────────────────
      # Prevents committing files over 500KB. Blocks accidental commits of
      # tfstate files, binaries, large logs, or secrets files.
      - id: check-added-large-files
        name: "L3 · block large files (>500KB)"
        args: [--maxkb=500]
        stages: [commit, push]

      # ── Additional hygiene hooks (recommended) ─────────────────────────────
      - id: end-of-file-fixer
        name: "L3 · end of file newline"
        stages: [commit]

      - id: check-merge-conflict
        name: "L3 · check merge conflicts"
        stages: [commit]

      - id: mixed-line-ending
        name: "L3 · mixed line endings"
        args: [--fix=lf]
        stages: [commit]

      - id: check-executables-have-shebangs
        name: "L3 · shebang on executables"
        stages: [commit]

      - id: no-commit-to-branch
        name: "L3 · no direct commits to main/master"
        args: [--branch=main, --branch=master]
        stages: [commit]
YAML

  success "${PRE_COMMIT_CONFIG} written"
}

# -----------------------------------------------------------------------------
# GENERATE .gitleaks.toml
# -----------------------------------------------------------------------------
generate_gitleaks_config() {
  step "Generating ${GITLEAKS_CONFIG}"

  if [[ -f "$GITLEAKS_CONFIG" ]] && ! confirm "Overwrite existing ${GITLEAKS_CONFIG}?"; then
    info "Keeping existing ${GITLEAKS_CONFIG}"
    return 0
  fi

  [[ "$DRY_RUN" == "true" ]] && { info "[dry-run] Would write ${GITLEAKS_CONFIG}"; return 0; }

  cat > "$GITLEAKS_CONFIG" <<'TOML'
# =============================================================================
# .gitleaks.toml
# Gitleaks configuration — custom rules and allowlist for this project
# Docs: https://github.com/gitleaks/gitleaks#configuration
# =============================================================================

title = "Terraform DevSecOps — Gitleaks Config"

[extend]
# Extend the default Gitleaks ruleset (recommended — inherits 100+ built-in rules)
useDefault = true

# =============================================================================
# CUSTOM RULES
# Add project-specific secret patterns below
# =============================================================================

[[rules]]
id          = "terraform-sensitive-variable"
description = "Terraform variable marked sensitive with a value assigned inline"
regex       = '''(?i)(sensitive\s*=\s*true[\s\S]{0,200}default\s*=\s*["'][^"']{8,}["'])'''
severity    = "HIGH"
tags        = ["terraform", "iac"]

[[rules]]
id          = "aws-account-id"
description = "Hardcoded AWS account ID"
regex       = '''\b\d{12}\b'''
severity    = "MEDIUM"
tags        = ["aws", "account"]

  [[rules.allowlist]]
  description = "Allow account IDs in example/test documentation"
  regexes     = ['''123456789012''', '''000000000000''']

[[rules]]
id          = "terraform-backend-bucket"
description = "Terraform S3 backend bucket name potentially containing env identifiers"
regex       = '''bucket\s*=\s*["'][a-z0-9-]*(prod|production|live)[a-z0-9-]*["']'''
severity    = "MEDIUM"
tags        = ["terraform", "backend", "aws"]

# =============================================================================
# GLOBAL ALLOWLIST — paths and patterns to always ignore
# =============================================================================

[allowlist]
description = "Global allowlist for known false positives"

# Ignore entire paths
paths = [
  '''.terraform''',
  '''\.terraform\.lock\.hcl''',
  '''\.tfstate''',
  '''\.tfstate\.backup''',
  '''terraform\.tfstate''',
  '''\.secrets\.baseline''',
  '''CHANGELOG\.md''',
  '''COST\.md''',
  '''docs/''',
]

# Ignore commits (useful for seed/example commits)
# commits = ["abcd1234"]

# Ignore known non-secret patterns that trigger false positives
regexes = [
  '''EXAMPLE_''',
  '''PLACEHOLDER_''',
  '''YOUR_''',
  '''<YOUR_''',
  '''example\.com''',
  '''localhost''',
  '''127\.0\.0\.1''',
  '''0\.0\.0\.0''',
]
TOML

  success "${GITLEAKS_CONFIG} written"
}

# -----------------------------------------------------------------------------
# GENERATE detect-secrets BASELINE
# -----------------------------------------------------------------------------
generate_secrets_baseline() {
  step "Initialising detect-secrets baseline"

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] Would run: detect-secrets scan > ${DETECT_SECRETS_BASELINE}"
    return 0
  fi

  if [[ -f "$DETECT_SECRETS_BASELINE" ]]; then
    info "Updating existing baseline (new secrets will be added)..."
    detect-secrets scan \
      --baseline "$DETECT_SECRETS_BASELINE" \
      --exclude-files '\.terraform/.*' \
      --exclude-files '\.tfstate.*' \
      --exclude-files '\.git/.*' \
      2>> "$LOG_FILE" || warn "detect-secrets baseline update returned non-zero (may be expected if no baseline existed)"
  else
    info "Creating new baseline..."
    detect-secrets scan \
      --exclude-files '\.terraform/.*' \
      --exclude-files '\.tfstate.*' \
      --exclude-files '\.git/.*' \
      > "$DETECT_SECRETS_BASELINE" 2>> "$LOG_FILE"
  fi

  success "${DETECT_SECRETS_BASELINE} ready ($(jq '.results | length' "$DETECT_SECRETS_BASELINE" 2>/dev/null || echo '?') file(s) tracked)"
}

# -----------------------------------------------------------------------------
# INSTALL GIT HOOKS
# -----------------------------------------------------------------------------
install_git_hooks() {
  step "Installing git hooks"

  run "pre-commit install --install-hooks"
  run "pre-commit install --hook-type commit-msg"
  run "pre-commit install --hook-type pre-push"

  success "Git hooks installed (.git/hooks/pre-commit, pre-push)"
}

# -----------------------------------------------------------------------------
# BASELINE RUN
# -----------------------------------------------------------------------------
run_baseline() {
  step "Running pre-commit baseline scan (all files)"

  if [[ "$CI_MODE" == "true" ]]; then
    info "CI mode — skipping interactive baseline run. Run manually: pre-commit run --all-files"
    return 0
  fi

  if ! confirm "Run 'pre-commit run --all-files' now? (recommended — may take a few minutes)"; then
    info "Skipping baseline run. Run it manually: pre-commit run --all-files"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] Would run: pre-commit run --all-files"
    return 0
  fi

  echo ""
  # Run and allow non-zero exit (some hooks auto-fix files and exit 1 on first run)
  if pre-commit run --all-files 2>&1 | tee -a "$LOG_FILE"; then
    success "Baseline scan passed"
  else
    warn "Some hooks reported failures or auto-fixed files."
    warn "This is normal on first run — hooks like terraform_fmt will reformat files."
    info "Review the output above, stage any auto-fixed files, and re-run."
  fi
}

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
print_summary() {
  separator
  echo -e "\n${BOLD}${GREEN}  Setup complete!${RESET}\n"

  cat <<EOF
${BOLD}  Files created / updated:${RESET}
  • ${PRE_COMMIT_CONFIG}      — hook definitions (all 3 layers)
  • ${GITLEAKS_CONFIG}               — Gitleaks custom rules + allowlist
  • ${DETECT_SECRETS_BASELINE}       — detect-secrets entropy baseline

${BOLD}  Git hooks installed:${RESET}
  • pre-commit    → Layers 1, 2, 3 (on every commit)
  • pre-push      → Trivy, Checkov, Terrascan, Gitleaks (on push)

${BOLD}  Useful commands:${RESET}
  pre-commit run --all-files          # Run all hooks on every file
  pre-commit run terraform_fmt        # Run a single hook
  pre-commit run --files infra/       # Run hooks on a specific path
  pre-commit autoupdate               # Bump hook versions to latest
  gitleaks detect --source . -v       # Manual Gitleaks full-repo scan
  detect-secrets scan > .secrets.baseline   # Regenerate baseline
  pre-commit uninstall                # Remove all git hooks

${BOLD}  Log:${RESET}
  $LOG_FILE

EOF
  separator
}

# -----------------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------------
main() {
  parse_args "$@"

  echo -e "\n${BOLD}${CYAN}  Enterprise Pre-Commit Setup${RESET} ${DIM}v${SCRIPT_VERSION}${RESET}"
  echo -e "  ${DIM}Terraform DevSecOps Pipeline — 3-Layer Security Framework${RESET}\n"
  separator

  [[ "$DRY_RUN" == "true" ]] && warn "DRY RUN mode — no changes will be made\n"

  detect_os
  check_prerequisites
  install_system_deps
  install_precommit
  install_terraform_tools
  install_secret_tools
  generate_precommit_config
  generate_gitleaks_config
  generate_secrets_baseline
  install_git_hooks
  run_baseline
  print_summary
}

main "$@"