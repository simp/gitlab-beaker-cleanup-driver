#!/bin/bash -Eeu
# ------------------------------------------------------------------------------
# GitLab Runner custom executor prepare script
# ------------------------------------------------------------------------------
# * Handles any custom actions necessary to set up the environment
# * See: https://docs.gitlab.com/runner/executors/custom.html#prepare
# ------------------------------------------------------------------------------
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# shellcheck source=base.sh
source "${script_dir}/base.sh"
banner "$(basename --suffix='.sh' "${BASH_SOURCE[0]}")"

#
# NOTE: There's nothing this stage needs to do (so far).
#

# Possibilities:
# ------------------------------------------------------------------------------
#   - Validate that RVM / the current Ruby Version is available to runner
#     - And if not: install it!
#   - Ensure that the cache is not messed up for this particular job
#     - What should we check for?
#     - In response to a problem, either;
#       a. Fix it (safely, without interfering with other jobs)
#       b. Fail the job immediately, with a helpful description that makes it
#          easier to figure out how to diagnose/fix the problem
# ------------------------------------------------------------------------------
