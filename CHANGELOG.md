# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Documentation for environment variables

### Fixed

- `ci_job_ensure_user_can_access_script` only chowns
  directory lineage from gitlab runner script in `base.sh`
  See note about [gitlab-runner#4804]

[gitlab-runner#4804]: https://gitlab.com/gitlab-org/gitlab-runner/-/issues/4804


## [0.5.0]

### Fixed

- Fixed bug in ci_job_pids to set local `__CI_JOB_TAG`
- Fixed `line 56: _CI_JOB_TAG: unbound variable` message at the end of base.sh
- Fixed `line 84: _CI_JOB_TAG: unbound variable` message at the end of base.sh
- Fixed `line 133: _CI_JOB_TAG: unbound variable` message at the end of base.sh
- Script no longer terminates if `/proc/$pid/cmdline` doesn't exist
- Error checking and logging for various commands
- Fixed `logger` choking on strings beginning with `-`

### Added

- Various bash `local` touch-ups (to be extra careful)
- `pipe_warn` function to stream and log output from important commands

### Changed

- Consolidated stop() logic in `base.sh`
- Build path uses `CI_CONCURRENT_ID` instead of `CI_CONCURRENT_PROJECT_ID`
- Build path uses `CI_PROJECT_NAMESPACE/CI_PROJECT_NAME` instead of
  `CI_PROJECT_PATH_SLUG`
  - Ref: https://docs.gitlab.com/runner/best_practice/#build-directory
- `ci_job_pids()` gives `$1` precedence over `$_CI_JOB_TAG`


## [0.4.1]

### Fixed

- 0.4.0 cleanup routines didn't clean up VMs because they ran `vboxmanage` and
  `vagrant` as `root` instead of `$CI_RUNNER_USER`.

## [0.4.0]

### Added

- Builds are now executed as an *unprivileged* user (default: `gitlab-runner`)
- base.sh:
  - Added variables with defaults: `$CI_RUNNER_USER` and `$CI_RUNNER_USER_DIR`
    - These specify the non-privileged build user & build/cache parent path
  - Added `banner()` function

### Changed

- Custom executor bumped to version 0.4.0
- `*_exec.sh` scripts now report only their basenames without extensions
- config_exec.sh now sources `base.sh` for default variable values
- base.sh is now silent on stdout as it is being sourced

### Fixed

- Tagged release version has been advanced to match the custom executor (`0.4.0`)
- Safety checks in `ci_job()`


## [0.1.1]

### Added

- Travis pipeline w/shellcheck validation

### Changed

- Fixed `line 101: _CI_JOB_TAG: unbound variable` message at the end of base.sh
- Updated scripts to pass shellcheck validation


## [0.1.0] - 2020-04-12

### Added

- Initial release


[0.1.0]: https://github.com/simp/gitlab-beaker-cleanup-driver/releases/tag/0.1.0
[0.1.1]: https://github.com/simp/gitlab-beaker-cleanup-driver/releases/tag/0.1.1
[0.4.0]: https://github.com/simp/gitlab-beaker-cleanup-driver/releases/tag/0.4.0
[0.4.1]: https://github.com/simp/gitlab-beaker-cleanup-driver/releases/tag/0.4.1
[0.5.0]: https://github.com/simp/gitlab-beaker-cleanup-driver/releases/tag/0.5.0
[Unreleased]: https://github.com/simp/gitlab-beaker-cleanup-driver/compare/0.5.0...HEAD
