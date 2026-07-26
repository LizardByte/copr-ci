<div align="center">
  <img
    src="https://raw.githubusercontent.com/LizardByte/.github/refs/heads/master/branding/logos/logo.svg"
    alt="LizardByte icon"
    width="256"
  />
  <h1 align="center">copr-ci</h1>
  <h4 align="center">Copr automation scripts for CI.</h4>
</div>

<div align="center">
  <a href="https://github.com/LizardByte/copr-ci/actions/workflows/ci.yml?query=branch%3Amaster"><img src="https://img.shields.io/github/actions/workflow/status/lizardbyte/copr-ci/ci.yml.svg?branch=master&label=CI%20build&logo=github&style=for-the-badge" alt="GitHub Workflow Status (CI)"></a>
  <a href="https://sonarcloud.io/project/overview?id=LizardByte_copr-ci"><img src="https://img.shields.io/sonar/quality_gate/LizardByte_copr-ci.svg?server=https%3A%2F%2Fsonarcloud.io&style=for-the-badge&logo=sonarqubecloud&label=sonarcloud" alt="SonarCloud"></a>
</div>

## Overview

Copr automation scripts for CI. This is meant to be used by LizardByte CI/CD pipeline.

## Usage

You can replicate this in your own org, by following the examples here.

1. Create 3 projects/repos in copr

   - `<org>/pulls` (fired on pull_request events)
   - `<org>/beta` (fired on prereleased events)
   - `<org>/stable` (fired on released events)

2. Add a workflow to your repo, like so.

   ```yml
   ---
   name: CI Copr

   on:
     pull_request:
       branches:
         - master
       types:
         - opened
         - synchronize
         - reopened
     release:
       types:
         - prereleased
         - released

   concurrency:
     group: "${{ github.workflow }}-${{ github.ref }}"
     cancel-in-progress: true

   jobs:
     call-copr-ci:
       uses: LizardByte/copr-ci/.github/workflows/copr-ci.yml@master
       with:
         copr_pr_webhook_token: "<fill in your pr token>"
         github_org_owner: "<fill in your org>"
         copr_ownername: "<fill in your copr owner>"
         auto_update_package: true
         job_timeout: 60
       secrets:
         COPR_BETA_WEBHOOK_TOKEN: ${{ secrets.COPR_BETA_WEBHOOK_TOKEN }}
         COPR_STABLE_WEBHOOK_TOKEN: ${{ secrets.COPR_STABLE_WEBHOOK_TOKEN }}
         COPR_CLI_CONFIG: ${{ secrets.COPR_CLI_CONFIG }}
   ```

3. Add the following secrets to the org:

   - `COPR_BETA_WEBHOOK_TOKEN`
   - `COPR_STABLE_WEBHOOK_TOKEN`
   - `COPR_CLI_CONFIG` - See https://copr.fedorainfracloud.org/api

   NOTE: The webhook secrets should only be the token portion of the webhook URL, not the full URL.

4. Optionally, add the following to the top of the spec file:

   ```rpmspec
   # sed will replace these values
   %global build_version 0
   %global branch 0
   %global commit 0

   Version: %{build_version}
   ```

5. Optionally, add a `.copr-ci` file to the root of your repo to exclude submodules or directories from the
   build. This is useful for reducing the size of the source tarball when large submodules are not needed for
   packaging. Each non-empty, non-comment line is treated as a path relative to the repo root to exclude.

   ```
   # .copr-ci - paths to exclude from the copr build tarball
   # Lines starting with '#' are comments and are ignored.

   # exclude an entire submodule
   third-party/build-deps

   # exclude a specific subdirectory inside a submodule
   third-party/build-deps/third-party/FFmpeg/AMF/Thirdparty
   ```

   Excluded paths are:
   - **Not initialized** as submodules (never cloned, saving time and bandwidth).
   - **Excluded** from the generated source tarball passed to rpmbuild.
