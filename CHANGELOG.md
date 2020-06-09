# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
