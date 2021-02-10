#!/bin/bash -Eeu
# ------------------------------------------------------------------------------
# GitLab Runner custom executor config script
# ------------------------------------------------------------------------------
# * Provides GitLab with information about the custom executor/"driver"
# * See: https://docs.gitlab.com/runner/executors/custom.html#config
# ------------------------------------------------------------------------------
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# shellcheck source=base.sh
source "${script_dir}/base.sh" >/dev/null 2>&1

cat << JSON
{
  "driver": {
    "name": "SIMP beaker cleanup driver",
    "version": "v0.5.1-rc0"
  },
  "builds_dir": "${CI_RUNNER_USER_DIR}/builds/${CUSTOM_ENV_CI_RUNNER_SHORT_TOKEN}/${CUSTOM_ENV_CI_CONCURRENT_ID}/${CUSTOM_ENV_CI_PROJECT_NAMESPACE}/${CUSTOM_ENV_CI_PROJECT_NAME}",
  "cache_dir":  "${CI_RUNNER_USER_DIR}/cache/${CUSTOM_ENV_CI_PROJECT_NAMESPACE}/${CUSTOM_ENV_CI_PROJECT_NAME}"
}
JSON
