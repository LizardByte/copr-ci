# copr-ci
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
