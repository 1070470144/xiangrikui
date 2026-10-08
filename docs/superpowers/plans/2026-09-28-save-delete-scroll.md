# Save Deletion and Scrollable Account List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add safe local-save deletion and a fixed-height scrollable save selector without clipping the account page controls.

**Architecture:** Keep persistence behavior in `main_menu.gd` through a public `delete_local_account()` operation. Build account rows inside a named `ScrollContainer`, and use a reusable `ConfirmationDialog` whose pending account name is resolved only after confirmation.

**Tech Stack:** Godot 4.7, GDScript, ConfigFile, Godot Control containers, existing headless test runner.

---

### Task 1: Define deletion behavior

**Files:** `tests/test_main_menu.gd`, `scripts/main_menu.gd`

- [ ] Add tests for non-current deletion, current-account fallback switching, missing-account rejection, and final-account protection.
- [ ] Run the unit test runner and confirm failure because `delete_local_account` is absent.
- [ ] Implement `delete_local_account(account_name: String) -> bool` and persistence.
- [ ] Re-run the unit test runner and confirm deletion tests pass.

### Task 2: Build the scrollable account selector

**Files:** `tests/test_main_menu.gd`, `scripts/main_menu.gd`

- [ ] Add a structure test for `AccountScroll/AccountList`.
- [ ] Run the unit test runner and confirm the structure test fails.
- [ ] Add scrollable rows, delete buttons, confirmation dialog, and a fixed creation area.
- [ ] Re-run the unit test runner and confirm the UI structure test passes.

### Task 3: Verify regression safety

**Files:** `scripts/main_menu.gd`, `tests/test_main_menu.gd`

- [ ] Run the full unit, integration, and content-system smoke tests.
- [ ] Run a headless project startup check.
- [ ] Run `git diff --check` and inspect the relevant diff.
