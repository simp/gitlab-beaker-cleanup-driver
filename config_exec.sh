#!/bin/bash -Eeu
# ------------------------------------------------------------------------------
# GitLab Runner custom executor config script
# ------------------------------------------------------------------------------
# * Provides GitLab with information about the custom executor/"driver"
# * See: https://docs.gitlab.com/runner/executors/custom.html#config
# ------------------------------------------------------------------------------
cat << JSON
{
  "driver": {
    "name": "SIMP beaker cleanup driver",
    "version": "v0.3.0"
  }
}
JSON
