#!/bin/bash -Eeu
# ------------------------------------------------------------------------------
# Sets up the _CI_JOB_TAG environment variable and other common behaviors
# ------------------------------------------------------------------------------
# * /proc/*/environ-tagging idea informed by https://serverfault.com/a/274613
# ------------------------------------------------------------------------------

set -o pipefail

_CI_JOB_TAG="${_CI_JOB_TAG:-"runner-${CUSTOM_ENV_CI_RUNNER_ID}-project-${CUSTOM_ENV_CI_PROJECT_ID}-concurrent-${CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID}-${CUSTOM_ENV_CI_JOB_ID}"}"

# Non-privileged user to execute the actual job script
CI_RUNNER_USER="${CI_RUNNER_USER:-gitlab-runner}"
CI_RUNNER_USER_DIR="${CI_RUNNER_USER_DIR:-/var/lib/$CI_RUNNER_USER}"

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


banner()
{
  banner="======================================="
  notice "$(printf "\n\n%s\n\n    %s:  _CI_JOB_TAG=%s\n%s\n\n" "$banner" "${2:-${1:-$0}}" "$_CI_JOB_TAG" "$banner")"
}

ci_job_pids()
{
  local __CI_JOB_TAG="${_CI_JOB_TAG:-$1}"
  # shellcheck disable=SC2153
  grep -l "\b_CI_JOB_TAG=$__CI_JOB_TAG\b" /proc/*/environ | cut -d/ -f3
}

ci_job_cmdlines()
{
  local -a pids
  pids=($(ci_job_pids))
  for pid in "${pids[@]}"; do
    echo "== $pid"
    local -a pid_cmdline
    pid_cmdline=($(strings -1 < "/proc/$pid/cmdline"))
    echo "${pid_cmdline[0]}"
    echo "${pid_cmdline[@]}"
    echo
  done
}

ci_job_stop_vbox()
{
  notice "== Cleaning up any leftover VirtualBox VMs (with _CI_JOB_TAG=${___ci_job_tag})"
  local -a pids
  if [ $# -gt 0 ]; then
    pids=("$@")
  else
    warn "== no pids to check"
    return 0
  fi

  local -a found_vbox_vms
  for pid in "${pids[@]}"; do
    local -a pid_cmdline
    pid_cmdline=($(strings -1 < "/proc/$pid/cmdline"))
    if [[ "$(basename "${pid_cmdline[0]}")" = "VBoxHeadless" ]]; then
      local vbox_vm="${pid_cmdline[2]}"
      local vbox_uuid="${pid_cmdline[4]}"
      found_vbox_vms+=("$vbox_uuid")
      warn "==== Deleting running VirtualBox VM '${vbox_vm}' (UUID='${vbox_uuid}') (pid='$pid')"
      runuser -l "$CI_RUNNER_USER" -c "vboxmanage controlvm '$vbox_uuid' poweroff"
      runuser -l "$CI_RUNNER_USER" -c "vboxmanage unregistervm '$vbox_uuid' --delete"
    fi
  done

  if [ "${#found_vbox_vms[@]}" -gt 0 ]; then
    warn "____ Deleted ${#found_vbox_vms[@]} VirtualBox VMs (with _CI_JOB_TAG=${_CI_JOB_TAG})"
    warn "==== Pruning any invalid vagrant environments"
    runuser -l "$CI_RUNNER_USER" -c 'vagrant global-status --prune'
  else
    notice "____ No leftover running VirtualBox VMs were found (with _CI_JOB_TAG=${_CI_JOB_TAG})"
  fi
}

ci_job_ensure_user_can_access_script()
{
  chown "$CI_RUNNER_USER" "$1"
  # shellcheck disable=SC2016
  [ -z "${TMPDIR:-}" ] && warn 'ci_job start: $TMPDIR env var is empty!'
  if [[ "$1" == "$TMPDIR"* ]]; then
    chown -R "$CI_RUNNER_USER" "$TMPDIR"
  else
    warn "ci_job start: TMPDIR does NOT contain the target script! (TMPDIR='$TMPDIR' script='$1')"
    warn "ci_job start (cont'd): build will probably fail with 'permission denied errors'"
  fi

  # Use namei to validate that the non-priv $CI_RUNNER_USER can access the
  # script AND its parent directories (required by the custom executor)
  local utmpdir
  utmpdir="$(runuser -l "$CI_RUNNER_USER" -c 'mktemp /tmp/beaker-cleanup-driver.XXXXXXXXXX' )"
  if ! runuser -l "$CI_RUNNER_USER" -c "namei -l '$1' &> '$utmpdir' "; then
    warn "$(cat "$utmpdir")"
    warn "ci_job start: FATAL: user $CI_RUNNER_USER cannot access '$1' (or one of its parents)!"
    rm -f "$utmpdir"
    echo exit 2
  fi
}

ci_job_kill_procs()
{
  local -a pids
  if [ $# -gt 0 ]; then
    pids=("$@")
    warn "== killing leftover pids (${#pids[@]}) (with _CI_JOB_TAG=$___ci_job_tag)"
  else
    warn "== no pids to check" && return 0
  fi
  for pid in "${pids[@]}"; do
    warn "==   $pid    $(cat "/proc/$pid/cmdline" || true)"
  done
  kill "${pids[@]}"
}

# Start / stop a CI job
#   $1:
#     start = execute script, setting $_CI_JOB_TAG on all child processes
#     stop  = kill any processes
#   $2: script to execute
ci_job()
{
  case "$1" in
  start)
    ci_job_ensure_user_can_access_script "$2"
    runuser -l "$CI_RUNNER_USER" -c "export _CI_JOB_TAG='$_CI_JOB_TAG'; '$2'"
    ;;
  stop)
    notice "== Stopping all related processes (with _CI_JOB_TAG=$_CI_JOB_TAG)"
    local ___ci_job_tag="$_CI_JOB_TAG"
    unset _CI_JOB_TAG  # don't kill ourselves
    local -a pids=($(ci_job_pids "$___ci_job_tag")) || true
    if [ "${#pids[@]}" -gt 0 ]; then
      ci_job_stop_vbox "${pids[@]}"
      sleep 8 # give post-VM processes a little time to die
      pids=($(ci_job_pids "$___ci_job_tag")) || true
      ci_job_kill_procs "${pids[@]}"
    fi

    notice "== Done stopping CI VMs + processes (with _CI_JOB_TAG=$___ci_job_tag)"
    ;;
  esac
}
