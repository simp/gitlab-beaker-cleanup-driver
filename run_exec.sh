#!/bin/bash -Eeu
# ------------------------------------------------------------------------------
# GitLab Runner custom executor run script
# ------------------------------------------------------------------------------
# * Executes during each of run's sub-stages
# * Arguments:
#      $1 = Path to script GitLab wants to run for this sub-stage
#      $2 = sub-stage name
# * STDOUT and STDERR returned from this script will print to the job log
# * See: https://docs.gitlab.com/runner/executors/custom.html#run
# ------------------------------------------------------------------------------
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# shellcheck source=base.sh
source "${script_dir}/base.sh"
banner "$(basename --suffix='.sh' "${BASH_SOURCE[0]}")[ $2 ]"

notice "  +--- Run sub stage $2 ---+: $1 (_CI_JOB_TAG=$_CI_JOB_TAG)"

env > "/tmp/custom_executor.$2.env"
echo "$1" > "/tmp/custom_executor.script-path.$2.txt"
cat "$1" > "/tmp/custom_executor.script-content.$2.txt"


ci_job start "$1"
