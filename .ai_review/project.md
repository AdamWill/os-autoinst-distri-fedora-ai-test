## Project Overview

**Purpose:** openQA test distribution for Fedora — contains test scripts, needle images, and template definitions used to automatically test Fedora installations, upgrades, desktop environments, and applications via the [openQA](http://os-autoinst.github.io/openQA/) framework.
**Type:** Test suite (openQA distribution)
**Domain:** OS-level automated QA for the Fedora Linux distribution
**Key Dependencies:** `os-autoinst` / `openQA` (test framework), `testapi` (openQA Perl test API), `fifloader.py` (custom FIF template loader)

## Technology Stack

### Versions (current as of 2026-03-04)
- **Perl** — all test code (`tests/*.pm`, `lib/*.pm`, `main.pm`)
- **Python** 3.10–3.14 — tooling only (`fifloader.py`, `check-needles.py`)
- **jsonschema** — FIF/openQA template validation (Python)
- **pytest** — Python unit tests for `fifloader.py`
- **tox** — Python test runner (envs: py310–py314, coverage-report)
- **perl-Code-TidyAll** + **perltidy** — Perl formatting enforcement
- **perl-Test-Strict** + **perl-Test-Harness** — Perl syntax/strictness checks
- **diff-cover** + **pylint** — coverage gating (90% on diff vs `origin/main`)

### CI (Forgejo Actions on Fedora)
- **tox job**: Validates FIF templates (`fifloader.py --clean`), runs `check-needles.py`, runs pytest
- **perl job**: Runs `prove t/` (perltidy + syntax checks on all `.pm` files)
- **checkwiki job**: Cross-validates templates against `fedora_openqa` wiki test cases
- **AI review**: Triggered by `ai-review-please` label, uses a reusable Gemini-based workflow

### Container Image
- CI runs on: `quay.io/fedora/fedora:latest`

## Architecture & Code Organization

### Structure
```
main.pm                    # Single entrypoint: loads tests based on variables
lib/
├── anacondatest.pm        # Base class for installer (Anaconda) tests
├── installedtest.pm       # Base class for post-install tests
├── anaconda.pm            # Exported functions for Anaconda UI interaction
├── utils.pm               # ~100 exported utility functions (typing, booting, login, repos...)
├── cockpit.pm             # Cockpit web UI helper functions
├── freeipa.pm             # FreeIPA test helpers
├── packagetest.pm         # Package install/remove test helpers
├── tapnet.pm              # Network/tap device helpers
├── bugzilla.pm            # Bug workaround tracking
├── disks.pm               # Disk/storage helpers
├── mock.pm                # Mock build helpers
├── mwriter.pm             # Fedora Media Writer helpers
└── fedoradistribution.pm  # Distribution-specific overrides for openQA
tests/
├── _boot_to_anaconda.pm   # Universal boot-to-installer test (auto-loaded)
├── _software_selection.pm # Package set selection (auto-loaded)
├── _do_install_and_reboot.pm # Install + reboot phase (auto-loaded)
├── disk_*.pm              # Partitioning tests (name matches PARTITIONING variable)
├── upgrade_*.pm           # Upgrade workflow tests
├── desktop_*.pm           # Desktop environment tests
├── applications/          # Per-app test modules (maps, papers, nautilus, etc.)
├── apps_startstop/        # Start/stop tests per desktop (gnome/, kde/)
└── _*.pm                  # Underscore-prefixed = internal/shared phases
needles/                   # ~1961 needle pairs (PNG screenshot + JSON tag definition)
├── anaconda/              # Installer UI needles
├── gnome/, kde/, i3/      # Desktop-specific needles
├── cockpit/, freeipa/     # Service-specific needles
└── console/, browser/     # Terminal and browser needles
templates.fif.json         # Main FIF template definitions (Machines, Products, Profiles, TestSuites)
templates-updates.fif.json # Update-testing template additions
fifloader.py               # FIF → openQA template converter/loader
check-needles.py           # Validates needle/tag consistency with test code
schemas/                   # JSON schemas for FIF and openQA template formats
```

### Key Patterns
- **Variable-driven test loading**: `main.pm` reads openQA variables (`DESKTOP`, `PARTITIONING`, `UPGRADE`, `ENTRYPOINT`, `POSTINSTALL`, etc.) to decide which test modules to load. Tests are composed modularly from shared phases.
- **Needle tag system**: Needles are PNG+JSON pairs. JSON defines tags used in `assert_screen`/`check_screen` calls. Tags prefixed with `LANGUAGE-`, `DESKTOP-`, or `INSTALLER-` are conditionally unregistered based on test variables.
- **Test inheritance**: Tests inherit from `anacondatest` (installer context, uploads Anaconda logs on failure) or `installedtest` (booted system context, handles emergency/dracut recovery on failure). Both provide `post_fail_hook`.
- **FIF template format**: Custom intermediate format (`templates.fif.json`) that's more human-readable than upstream openQA templates. Defines Profiles (Machine+Product pairs) and assigns them to TestSuites. `fifloader.py` converts to upstream format.
- **Workaround pattern**: Temporary workarounds for upstream bugs are common (cockpit scratch builds, SELinux permissive, package version pins). These are tracked in commits and removed when the upstream bug is fixed.

### Critical Files
- **`main.pm`** — All test loading logic. Changes here affect which tests run for every job. Must understand variable interactions.
- **`lib/utils.pm`** — ~2000 lines, ~100 exported functions used everywhere. Changes have broad impact.
- **`lib/anaconda.pm`** — Anaconda UI interaction functions including `select_disks`, partitioning, user creation. Handles both GTK and WebUI Anaconda variants.
- **`templates.fif.json`** — Defines all machines, products, profiles, and test suites. Must pass `fifloader.py --clean` validation and JSON schema checks.
- **`fifloader.py`** — Template converter. Changes affect all template loading. Has its own unit tests and JSON schemas.
- **`check-needles.py`** — Catches unused needles and missing needle references. Has an exceptions system for known edge cases.

## Review Guidance

### What Reviewers Must Know
- **openQA API is Perl, not standard Perl**: Functions like `assert_screen`, `check_screen`, `assert_and_click`, `type_string`, `send_key`, `script_run`, `assert_script_run`, `wait_serial`, `get_var`, `set_var`, `save_screenshot`, and `upload_logs` come from the `testapi` module provided by os-autoinst. Do not suggest replacements or flag them as undefined.
- **`script_run` vs `assert_script_run`**: `script_run` returns the exit code (0 = success); `assert_script_run` dies on non-zero exit. Both accept a timeout parameter. The choice between them is intentional.
- **Needle tags are string identifiers, not file paths**: When you see `assert_screen "some_tag"`, the string refers to a tag defined in a needle JSON file, not a filename. Multiple needles can share the same tag.
- **Underscore-prefixed tests are shared phases**: Files like `_boot_to_anaconda.pm`, `_console_wait_login.pm` are loaded by `main.pm` as part of composite test flows, not run standalone.
- **Test variable names are openQA conventions**: `DESKTOP`, `PARTITIONING`, `POSTINSTALL`, `BOOTFROM`, `LIVE`, `UPGRADE`, etc. are set by the test scheduler, not in the code. See `VARIABLES.md` for the full list.
- **Symlink instances for duplicate module loading**: openQA doesn't handle loading the same module twice well, so `_2`, `_3` suffixed symlinks exist for modules that need to be loaded multiple times in one test flow.

### Do NOT Flag
- **`use strict` without `use warnings`** — openQA's `testapi` module handles warnings configuration. Adding `use warnings` can cause spurious noise.
- **`die` for flow control in tests** — Standard openQA pattern. `die` triggers the test's `post_fail_hook` for log collection. Do not suggest exception handling.
- **Magic string comparisons with `get_var`** — Variable values like `"Rawhide"`, `"minimal"`, `"gnome"` are openQA conventions, not magic strings.
- **`sleep` calls between UI interactions** — Often necessary to handle animation delays, screen transitions, or flaky timing in VM-based GUI testing. Do not suggest removing them without understanding the context.
- **Long export lists in `lib/*.pm`** — These are Perl's mechanism for making functions available to test scripts. The pattern is standard for this codebase.
- **`wait_still_screen` with specific `similarity_level`** — The non-default similarity levels (e.g., 38) are calibrated for screens with blinking cursors or animations. Do not suggest using defaults.

### Common Pitfalls
- **Needle tag hygiene**: Adding a needle without proper `LANGUAGE-`, `DESKTOP-`, or other prefix tags can cause it to match in wrong test contexts. `check-needles.py` catches missing references but not incorrect tag scoping.
- **Template validation**: Changes to `templates.fif.json` or `templates-updates.fif.json` must pass `fifloader.py --clean` (which validates against JSON schemas in `schemas/`). Test suites need matching profiles.
- **Anaconda GTK vs WebUI divergence**: Anaconda has both a traditional GTK UI and a newer WebUI (`_ANACONDA_WEBUI` variable). Functions in `lib/anaconda.pm` often branch on this. New installer tests should handle both paths.
- **Workaround lifecycle**: Workarounds are added frequently for upstream bugs (git history shows many "Add workaround" / "Drop workaround" pairs). Workarounds should reference bug IDs (RHBZ#, upstream issue) and be removed when fixed.

## Internal & Proprietary

- **`fifloader.py` / FIF format**: Entirely custom to this project. Converts Fedora Intermediate Format templates to upstream openQA format. Has its own JSON schemas (`schemas/fif-*.json`) and unit tests (`unittests/test_fifloader.py`). The FIF format documentation is in `fifloader.py`'s docstring.
- **`check-needles.py`**: Custom script that cross-references needle tags with test code to find unused needles and unresolved tag references. Has an exceptions/allowlist system.
- **`fedora_openqa`** (external): The scheduling tool at `forge.fedoraproject.org/quality/fedora_openqa` that posts jobs to openQA. Its `conf_test_suites.py` must stay in sync with test suites defined here.
- **`createhdds`** (external): Tool at `forge.fedoraproject.org/quality/createhdds` for creating base disk images used by tests.
- **Fedora Forge**: The project's primary hosting is on Forgejo at `forge.fedoraproject.org`, not GitHub. PRs follow a GitHub-style workflow.

---
<!-- MANUAL SECTIONS - DO NOT MODIFY THIS LINE -->

## Architecture & Design Decisions

- **Modular test composition via `main.pm`**: Rather than each test being a standalone script, `main.pm` assembles test flows from reusable phases based on variables. This allows combinatorial testing (e.g., UEFI + encrypted + KDE) without duplicating test code.
- **FIF over upstream templates**: The upstream openQA template format requires defining a JobTemplate per test-per-machine-per-product combination. FIF inverts this: test suites declare which profiles they run on. This dramatically reduces boilerplate when adding new tests.
- **Needle-based visual matching over OCR**: openQA uses screenshot comparison (needles) rather than OCR for GUI testing. This means UI changes (new themes, font changes, background changes) require needle updates — visible as the many needle-update commits in history.

## Business Logic

- **Test flow phases**: Install tests follow: boot → Anaconda customization → install+reboot → post-install checks. Upgrade tests follow: boot → pre-upgrade → upgrade run → post-upgrade checks. The `POSTINSTALL` variable chains arbitrary post-install test modules.
- **Advisory/update testing workflow**: When `ADVISORY_OR_TASK` is set, the test installs a Fedora advisory's packages after initial install, reboots, then runs post-install tests. This tests that updates don't break the system.
- **Rawhide vs branched release handling**: `get_release_number()` in `utils.pm` maps `"Rawhide"` to `RAWREL` to allow numeric comparisons. Many conditionals check release numbers to handle cross-version differences.

## Domain-Specific Context

- **openQA**: An automated testing framework that boots VMs, interacts with them via keyboard/mouse simulation, and validates screen contents against reference screenshots (needles).
- **Anaconda**: Fedora's OS installer. Has a "hub and spoke" GUI where users configure installation options (disk, network, packages) from a central hub before starting installation.
- **Needles**: PNG+JSON pairs where the PNG is a reference screenshot region and the JSON defines match tags and areas. Multiple needles can match the same tag (variants for different contexts).
- **Koji/Bodhi**: Fedora's build and update systems. `ADVISORY_OR_TASK` refers to a Bodhi update advisory or Koji build task ID.

## Special Cases

- **`ENTRYPOINT` bypass**: Setting `ENTRYPOINT` skips the entire modular `main.pm` flow and directly loads the specified test module(s). Used for tests that don't fit the install/post-install pattern.
- **`CANNED` image type**: Refers to pre-built installer images (like Silverblue/Kinoite) that have a smaller Anaconda hub without repository spokes. Handled similarly to `LIVE` for hub needle selection.
- **CoreOS**: Has its own entirely separate install flow (`_coreos_install.pm`) that bypasses the normal Anaconda-based installation.
- **Multi-instance symlinks**: Files like `_console_wait_login_2.pm` are symlinks to `_console_wait_login.pm`, allowing `main.pm` to load the same test logic twice in one job (openQA limitation).
