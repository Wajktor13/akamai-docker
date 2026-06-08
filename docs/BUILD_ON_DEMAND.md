# Build On Demand

This document describes the **Build On Demand** GitHub Actions workflow, which allows any developer to build and test Docker images from any branch without pushing to DockerHub.

## Why this workflow exists

The default `Docker Image CI` workflow only runs on push to `master` (or on a version tag), and it always pushes to DockerHub. This means build failures are caught only after merging — and the only pre-merge option was a local build, which cannot catch GitHub Actions-specific issues.

The **Build On Demand** workflow solves this:
- Runs fully inside GitHub Actions (no local Docker required)
- Works from **any branch**
- Does **not** push to DockerHub by default
- Supports building all variants or a specific subset
- Supports running all tests or a specific subset

---

## How to trigger

1. Go to the **Actions** tab in the GitHub repository.
2. Select **Build On Demand** from the left-hand workflow list.
3. Click **Run workflow**.
4. Fill in the inputs (see below) and click **Run workflow**.

---

## Inputs

| Input | Default | Description |
|---|---|---|
| `variants` | *(empty — build all)* | Build chains to build, one per line. Each line is a space-separated chain. Leave empty to build everything in the `variants` file. |
| `test_files` | `test.bats` | Comma-separated test files to run. Leave empty to skip tests. |
| `test_image` | `akamai/shell` | Docker image to run tests against (without the `:local-*` suffix). |
| `push` | `false` | Whether to push built images to DockerHub. Requires `DOCKER_USERNAME` / `DOCKER_PASSWORD` secrets. |

---

## Usage examples

### 1. Build and test everything (no push)

The default — leave all inputs as-is and click **Run workflow**.

```
variants:    (empty)
test_files:  test.bats
test_image:  akamai/shell
push:        false
```

Builds every chain from `variants`, runs `test.bats` against `akamai/shell`, does not push.

---

### 2. Build and test a single variant

To build only the `appsec` image (which depends on `cli`, which depends on `base`):

```
variants:    base cli
             cli appsec
test_files:  test.bats
test_image:  akamai/shell
push:        false
```

The `variants` input mirrors the line format of the `variants` file — each line is a full dependency chain, left to right. In this example:
- Line 1 builds: `base` → `cli`
- Line 2 builds: `cli` → `appsec`

> **Tip:** Check the `variants` file in the repo root to see the full dependency chains for each image.

---

### 3. Build only, no tests

```
variants:    base cli
             cli appsec
test_files:  (empty)
test_image:  akamai/shell
push:        false
```

Leaving `test_files` empty skips the test step entirely.

---

### 4. Run with a custom test file

If you have added a new bats test file (e.g. `test-appsec.bats`):

```
variants:    base cli
             cli appsec
test_files:  test-appsec.bats
test_image:  akamai/appsec
push:        false
```

`test_image` is set to the image you want to test against. Multiple files can be comma-separated: `test.bats,test-appsec.bats`.

---

### 5. Build, test, and push (for release)

When you want to push to DockerHub (e.g. from a stable branch):

```
variants:    (empty — build all)
test_files:  test.bats
test_image:  akamai/shell
push:        true
```

This requires that `DOCKER_USERNAME` and `DOCKER_PASSWORD` repository secrets are configured.

---

## How variants and chains work

The `variants` file lists all images and their dependency chains:

```
base                      # standalone: builds akamai/base
base cli                  # builds base first, then cli on top
cli appsec                # builds cli first, then appsec on top
property-manager onboard  # builds property-manager first, then onboard on top
```

When you pass variants to this workflow, provide the **same chain format** — one chain per line. The workflow calls `scripts/build-chain.sh` once per line, in order.

If you leave `variants` empty, the workflow calls `scripts/build-all.sh` which processes every line in the `variants` file automatically.

---

## Differences from the main CI workflow

| | `Docker Image CI` | `Build On Demand` |
|---|---|---|
| Trigger | Push to `master` / tag / schedule | Manual (`workflow_dispatch`) |
| Branch | `master` only | Any branch |
| Push to DockerHub | Always | Only when `push: true` |
| Variant selection | All | All or subset |
| Test selection | All (`test.bats`) | Configurable or skipped |
