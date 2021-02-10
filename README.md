# Beaker Cleanup Driver for GitLab Runners

<!-- vim-markdown-toc GFM -->

* [Description](#description)
* [Requirements](#requirements)
* [Setup](#setup)
  * [1. Installing the executor files](#1-installing-the-executor-files)
  * [2. Registering new Runner(s) using the configuration template file](#2-registering-new-runners-using-the-configuration-template-file)
* [Reference](#reference)
  * [Environment variables](#environment-variables)
  * [How the executor knows what VMs to clean up](#how-the-executor-knows-what-vms-to-clean-up)
  * [Troubleshooting](#troubleshooting)
    * [journald logs on syslog identifier `beaker-cleanup-driver`](#journald-logs-on-syslog-identifier-beaker-cleanup-driver)
    * [journald logs for `gitlab-runner` service](#journald-logs-for-gitlab-runner-service)
      * [Limitations](#limitations)

<!-- vim-markdown-toc -->

![](assets/beaker-cleanup-driver.gif)

## Description

**beaker-cleanup-driver** is a GitLab CI runner [custom executor][custom
executor] that properly cleans up each CI job's child processes and VMs―even if
the job failed, was cancelled, or timed out (probably).

1. Drop-in alternative to the shell executor
2. Tracks all processes created by a CI job and stops them after it terminates.
3. Includes special logic to clean up Virtual Box VMs and Vagrant sessions
   * (Using their respective tooling in order to properly reclaim their disk resources)

It is designed to run multi-node acceptance tests using Puppet's
[Beaker][beaker] while avoiding the shell executor's tendency to
accumulate hundreds of gigs of disk space and running VM processes, left
over from jobs that didn't terminate cleanly.


## Requirements

* Gitlab CI Runner 11+
* Linux host (tested on CentOS 7)
* bash

## Setup

### 1. Installing the executor files

As root, clone the contents of this repository into a directory on the runner,
and make sure that the `gitlab-runner` user can read and execute the directory
path and the `*.sh` scripts:

```sh

# We'll keep using this $CUSTOM_EXECUTOR_DIR in the next example, too
CUSTOM_EXECUTOR_DIR=/opt/simp/gitlab-runner/beaker-cleanup-driver
THIS_REPOSITORY_URL="<the url of this git repository>"

umask 0027
git clone "$THIS_REPOSITORY_URL" "$CUSTOM_EXECUTOR_DIR"

# Ensure that gitlab-runner can read and execute the scripts
chgrp -R gitlab-runner "$CUSTOM_EXECUTOR_DIR"
chmod -R g=u-w "$CUSTOM_EXECUTOR_DIR"
```

### 2. Registering new Runner(s) using the configuration template file

A Gitlab Runner [configuration template file][configuration template file]
is provided to simplify registration.

1. Tailor the template file `beaker-cleanup-driver.template.toml`

   * Make sure the `_exec` entries in the `[runners.custom]` section are under the
     path where you cloned the repository (`$CUSTOM_EXECUTOR_DIR`).
   * Tailor settings to taste (not everybody needs `log_level = 'debug')

2. Register a new GitLab Runner using the `--template-config` option:

```sh
gitlab-runner register \
  --name "$RUNNER_NAME" \
  --registration-token "$REGISTRATION_TOKEN" \
  --url "${CI_SERVER_URL:-https://gitlab.com/}" \
  --executor custom \
  --template-config "$CUSTOM_EXECUTOR_DIR/beaker-cleanup-driver.template.toml" \
  --tag-list "${RUNNER_TAG_LIST:-beaker}" \
  --non-interactive \
  --paused \
  --locked
```
For more information, see GitLab's documentation about [Registering Runners][registering runners]

## Reference


### Environment variables

You can set environment variables (in the `job_env` key of the executor's `config_exec.sh` script<sup>[[0]]</sup>)


| Environment Variable | Purpose                                                             | Default                      |
|----------------------|---------------------------------------------------------------------|------------------------------|
| `CI_RUNNER_USER`     | non-privileged build user                                           | `gitlab-runner`              |
| `CI_RUNNER_USER_DIR` | parent path for non-privileged build user's build/cache directories | `/var/lib/${CI_RUNNER_USER}` |

### How the executor knows what VMs to clean up

Beaker (and its VM orchestration) does not lend itself to using PID files, so
instead the custom executor "tags" every process it starts with a unique
environment variable:

1. The exec script in each stage sets an environment variable `$_CI_JOB_TAG` to
   a value that is unique to the job
2. Every runner script for the job executes with `$_CI_JOB_TAG` set to this same
   value.
3. When the `cleanup_exec` stage executes, all processes with `$_CI_JOB_TAG` set
   to that value will be cleaned up.
   - Running VirtualBox VMs will be shut down and deleted
   - `vagrant global-status --prune` will run if any VMs were shut down
   - after a short grace period, all remaining processes
4. The environment variables are found by grepping `/proc/*/environ` for the
   job's unique `$_CI_JOB_TAG` value
5. VMs are idenitified by grepping each `$_CI_JOB_TAG` pid's associated
   `/proc/$pid/cmdline` for VBoxHeadless

The technique of tagging processes for later cleanup using environment
variables (and identifying them via `/proc/*/environ`) was informed by the
discussion at https://serverfault.com/a/274613 .


### Troubleshooting

#### journald logs on syslog identifier `beaker-cleanup-driver`

The custom executor logs its activity to the Runner console output and to
journald under the syslog identifier `beaker-cleanup-driver`.

You can follow these messages via `journalctl`:

        journalctl -t beaker-cleanup-driver -f

While troubleshooting, you are likely to only be interested in messages from a
single job.  To see a specific job's progress, grep for the job's unique
`_CI_JOB_TAG` value (shown in the Runner console output at the beginning of
every exec stage and sub-stage):

        journalctl -t beaker-cleanup-driver -n 3000 -e  | egrep _CI_JOB_TAG=runner-1751173-project-17669670-concurrent-0-487152645 -A5 -B6 | less

#### journald logs for `gitlab-runner` service

The `gitlab-runner` unit's journald log can also be useful for correlating the
Runner's communication and setup events during troubleshooting.  Depending on
the gitlab-runner's `debug_level`, some executor messages (ONLY from the
`cleanup_exec` stage) will also appear in this log.

You can follow the unit's log via `journalctl`:

        journalctl -u gitlab-runner -f -n 3000

The gitlab-runner's log can have a lot of noise in addition to the executor
output To help filter the noise, you can grep the logs:

        journalctl -u gitlab-runner  -e -n 3000   | egrep '==|--' | less

To follow a specific job's progress, grep for the _CI_JOB_TAG value (shown in
the Runner console output at the beginning of every exec stage and sub-stage):

        journalctl -u gitlab-runner -e | grep _CI_JOB_TAG=runner-1751173-project-17669670-concurrent-0-485904412


##### Limitations

* The `gitlab-runner` unit's journald log only includes output from the
  `cleanup_exec` script (when `log_level` is `warn` or higher)
* There can be a signifcant delay before the messages show up at all.

[registering runners]: https://docs.gitlab.com/runner/register/
[configuration template file]: https://docs.gitlab.com/runner/register/#runners-configuration-template-file
[custom executor]: https://docs.gitlab.com/runner/executors/custom.html
[beaker]: https://github.com/puppetlabs/beaker
[0]: https://docs.gitlab.com/runner/executors/custom.html#config
