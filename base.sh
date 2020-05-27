#!/bin/bash -Eeu
# ------------------------------------------------------------------------------
# Sets up the _CI_JOB_TAG environment variable and other common behaviors
# ------------------------------------------------------------------------------
# * /proc/*/environ-tagging idea informed by https://serverfault.com/a/274613
# ------------------------------------------------------------------------------

set -o pipefail

_CI_JOB_TAG="${_CI_JOB_TAG:-"runner-${CUSTOM_ENV_CI_RUNNER_ID}-project-${CUSTOM_ENV_CI_PROJECT_ID}-concurrent-${CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID}-${CUSTOM_ENV_CI_JOB_ID}"}"

notice()
{
  echo "${@}"
  logger -t beaker-cleanup-driver "${@}"
}

warn()
{
  >&2 echo "${@}"
  logger -t beaker-cleanup-driver "${@}"
}

banner="======================================="
notice "$(printf "\n\n%s\n\n    %s\n\n    _CI_JOB_TAG=%s\n%s\n\n" "$banner" "${2:-${1:-$0}}" "$_CI_JOB_TAG" "$banner")"

ci_job_pids()
{
  local __CI_JOB_TAG"=${_CI_JOB_TAG:-$1}"
  # shellcheck disable=SC2153
  grep -l "\b_CI_JOB_TAG=$__CI_JOB_TAG\b" /proc/*/environ | cut -d/ -f3
}

ci_job_cmdlines()
{
  local pids=($(ci_job_pids))
  for pid in "${pids[@]}"; do
    echo "== $pid"
    local pid_cmdline=($(strings -1 < "/proc/$pid/cmdline"))
    echo "${pid_cmdline[0]}"
    echo "${pid_cmdline[@]}"
    echo
  done
}

ci_job_stop_vbox()
{
  notice "== Cleaning up any leftover VirtualBox VMs (with _CI_JOB_TAG=${_CI_JOB_TAG})"
  if [ $# -gt 0 ]; then
    local pids=("$@")
  else
    local pids=($(ci_job_pids))
  fi

  local found_vbox_vms=()
  for pid in "${pids[@]}"; do
    local pid_cmdline=($(strings -1 < "/proc/$pid/cmdline"))
    if [[ "$(basename "${pid_cmdline[0]}")" = "VBoxHeadless" ]]; then
      local vbox_vm="${pid_cmdline[2]}"
      local vbox_uuid="${pid_cmdline[4]}"
      found_vbox_vms+=("$vbox_uuid")
      warn "==== Deleting running VirtualBox VM '${vbox_vm}' (UUID='${vbox_uuid}') (pid='$pid')"
      vboxmanage controlvm "$vbox_uuid" poweroff
      vboxmanage unregistervm "$vbox_uuid" --delete
    fi
  done

  if [ "${#found_vbox_vms[@]}" -gt 0 ]; then
    warn "____ Deleted ${#found_vbox_vms[@]} VirtualBox VMs (with _CI_JOB_TAG=${_CI_JOB_TAG})"
    warn "==== Pruning any invalid vagrant environments"
    vagrant global-status --prune
  else
    notice "____ No leftover running VirtualBox VMs were found (with _CI_JOB_TAG=${_CI_JOB_TAG})"
  fi
}

# Start / stop a CI job
#   start = keeping track of all child processes via $_CI_JOB_TAG
#   stop
ci_job()
{
  case "$1" in
  start)
    _CI_JOB_TAG="$_CI_JOB_TAG" "$2"
    ;;
  stop)
    notice "== Stopping all related processes (with _CI_JOB_TAG=$_CI_JOB_TAG)"
    local pids=($(ci_job_pids))
    ci_job_stop_vbox "${pids[@]}"

    sleep 8 # give post-VM processes a little time to die
    local ___ci_job_tag="$_CI_JOB_TAG"
    unset _CI_JOB_TAG  # don't kill ourselves
    local pids=($(ci_job_pids "$___ci_job_tag"))
    if [ "${#pids[@]}" -gt 0 ]; then
      warn "== killing leftover pids (${#pids[@]}) (with _CI_JOB_TAG=$___ci_job_tag)"
       for pid in "${pids[@]}"; do
         warn "==   $pid    $(cat "/proc/$pid/cmdline" || true)"
       done
       kill "${pids[@]}"
    fi
    notice "== Done stopping CI VMs + processes (with _CI_JOB_TAG=$___ci_job_tag)"
    ;;
  esac
}
