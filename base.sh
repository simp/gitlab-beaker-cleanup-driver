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
_CI_RUNNER_USER_DIR_autodetect="$(getent passwd "$CI_RUNNER_USER" | cut -d: -f6)"
CI_RUNNER_USER_DIR="${CI_RUNNER_USER_DIR:-${_CI_RUNNER_USER_DIR_autodetect:-/var/lib/$CI_RUNNER_USER}}"
unset _CI_RUNNER_USER_DIR_autodetect

notice()
{
  echo "${@}"
  if command -v systemd-cat > /dev/null; then
    echo "${@}" | systemd-cat -t beaker-cleanup-driver -p info
  else
    logger -t beaker-cleanup-driver -- "${@}"
  fi
}

warn()
{
  >&2 echo "${@}"
  if command -v systemd-cat > /dev/null; then
    echo "${@}" | systemd-cat -t beaker-cleanup-driver -p warning
  else
    logger -t beaker-cleanup-driver -- "${@}"
  fi
}

pipe_notice()
{
   while IFS="" read -r data; do
     notice "$data"
   done
}

pipe_warn()
{
   while IFS="" read -r data; do
     warn "$data"
   done
}


banner()
{
  banner="======================================="
  notice "$(printf "\n\n%s\n\n    %s:  _CI_JOB_TAG=%s\n%s\n\n" "$banner" "${2:-${1:-$0}}" "$_CI_JOB_TAG" "$banner")"
}

ci_job_pids()
{
  local __CI_JOB_TAG="${1:-"${_CI_JOB_TAG:-NO_ARG_OR_ENV_VAR_GIVEN}"}"
  # shellcheck disable=SC2153
  grep -l "\b_CI_JOB_TAG=$__CI_JOB_TAG\b" /proc/*/environ | cut -d/ -f3
}

ci_job_cmdlines()
{
  local -a pids
  pids=($(ci_job_pids))
  for pid in "${pids[@]}"; do
    [ -f "/proc/$pid/cmdline" ] || continue
    echo "== $pid"
    local -a pid_cmdline
    pid_cmdline=($(strings -1 < "/proc/$pid/cmdline"))
    echo "${pid_cmdline[0]}"
    echo "${pid_cmdline[@]}"
    echo
  done
}


# $@             = pids of VirtualBox VMs to stop
# $___ci_job_tag = outside-scope variable with _CI_JOB_TAG to kill
ci_job_stop_vbox()
{
  local -a pids
  if [ $# -gt 0 ]; then
    pids=("$@")
  else
    warn "== no pids to check"
    return 0
  fi

  local -a found_vbox_vms
  for pid in "${pids[@]}"; do
    [ -f "/proc/$pid/cmdline" ] || continue
    local -a pid_cmdline
    pid_cmdline=($(strings -1 < "/proc/$pid/cmdline")) || true
    if [[ "$(basename "${pid_cmdline[0]}")" = "VBoxHeadless" ]]; then
      local vbox_vm="${pid_cmdline[2]}"
      local vbox_uuid="${pid_cmdline[4]}"
      found_vbox_vms+=("$vbox_uuid")e

      warn "==== Powering off running VirtualBox VM '${vbox_vm}' (UUID='${vbox_uuid}') (pid='$pid')"
      pipe_warn < <(runuser -l "$CI_RUNNER_USER" -c "vboxmanage controlvm '$vbox_uuid' poweroff" 2>&1 ) || \
        warn "  !! poweroff failed for VM '${vbox_vm}'"

      warn "==== Unregistering VirtualBox VM '${vbox_vm}' (UUID='${vbox_uuid}') (pid='$pid')"
      pipe_warn < <(runuser -l "$CI_RUNNER_USER" -c "vboxmanage unregistervm '$vbox_uuid' --delete" 2>&1) || \
        warn "  !! unregistervm failed for VM '${vbox_vm}'"
    fi
  done

  if [ "${#found_vbox_vms[@]}" -gt 0 ]; then
    warn "____ Deleted ${#found_vbox_vms[@]} VirtualBox VMs (with _CI_JOB_TAG=${___ci_job_tag})"
    warn "==== Pruning any invalid vagrant environments"
    pipe_warn < <(runuser -l "$CI_RUNNER_USER" -c 'vagrant global-status --prune' 2>&1 || \
      echo "  !! 'vagrant global-status --prune' failed with exit code '$?'")
  else
    notice "____ No leftover running VirtualBox VMs were found (with _CI_JOB_TAG=${___ci_job_tag})"
  fi
}

ci_stop_tagged_jobs()
{
  local ___ci_job_tag="$1"
  local -a pids
  pids=($(ci_job_pids "$___ci_job_tag")) || true
  if [ "${#pids[@]}" -eq 0 ]; then
    warn "== no pids to check" && return 0
  fi

  notice "== Stopping any vagrant boxes running out of '$CUSTOM_ENV_CI_PROJECT_DIR/.vagrant/beaker_vagrant_files/default.yml'"
  pipe_warn < <(runuser -l "$CI_RUNNER_USER" -c 'vagrant global-status --prune' \
    | grep "$CUSTOM_ENV_CI_PROJECT_DIR/.vagrant/beaker_vagrant_files/default.yml" \
    | xargs -i runuser -l "$CI_RUNNER_USER" -c  "vagrant destroy -f {}" 2>&1 ) || warn "  !! exit-code: '$0'"

  notice "== Cleaning up any leftover VirtualBox VMs (with _CI_JOB_TAG=${___ci_job_tag})"
  ci_job_stop_vbox "${pids[@]}"
  sleep 8 # give post-VM processes a little time to die

  pids=($(ci_job_pids "$___ci_job_tag")) || true
  if [ "${#pids}" -gt 0 ]; then
    notice "== killing leftover pids (${#pids[@]}) (with _CI_JOB_TAG=$___ci_job_tag)"
    for pid in "${pids[@]}"; do
      [ -f "/proc/$pid/cmdline" ] || continue
      warn "==   $pid    $(cat "/proc/$pid/cmdline" || true)"
    done
    kill "${pids[@]}"
  fi
}

# Start / stop a CI job
#   $1:
#     start = execute script, setting $_CI_JOB_TAG on all child processes
#     stop  = kill any processes
#   $2: path to executable stage script (provided by GitLab Runner)
ci_job()
{
  case "$1" in
  start)
    #
    # Situation:
    #
    # - GitLab Runner always writes custom executors' stage scripts under /tmp.
    # - These scripts (and their parent directories) are created as root/0700.
    # - The scripts' path, owner, and mode are not configurable.
    #
    #     https://gitlab.com/gitlab-org/gitlab-runner/-/issues/4804
    #
    # Problems:
    #
    # 1. Although the GitLab Runner writes the scripts as root/0700, we need
    #    to execute them with a non-privileged user (gitlab-runner). However,
    #    the restricted permisions prevent any non-privileged user from
    #    accessing the scripts (and their parent directories).
    #
    # 2. Naively relaxing stage scripts' owner/perms in order to grant access
    #    to the non-privileged user would introduce a small (but real) window
    #    of opportunity for malicious code from concurrently-executing
    #    pipelines to steal secrets from other projects.
    #
    # 3. /tmp is often mounted as `noexec` on hardened systems.  This prevents
    #    *any* user from executing the custom executor's stage scripts, even if
    #    they are permitted to access them.
    #
    # Solution:
    #
    #   The wily abomination below (inspired by a GL dev's comment in #4804)
    #
    script_content="$(cat "$2")"
    runuser -l "$CI_RUNNER_USER" -c "export _CI_JOB_TAG='$_CI_JOB_TAG'; $script_content"
    ;;
  stop)
    notice "== Stopping all related processes (with _CI_JOB_TAG=$_CI_JOB_TAG)"
    local ___ci_job_tag="$_CI_JOB_TAG"
    unset _CI_JOB_TAG  # (don't kill ourselves)
    ci_stop_tagged_jobs "$___ci_job_tag"
    notice "== Done stopping CI VMs + processes (with _CI_JOB_TAG=$___ci_job_tag)"
    ;;
  esac
}
