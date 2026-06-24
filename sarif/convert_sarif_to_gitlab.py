#!/usr/bin/env python3
"""DEPRECATED: NightVision emits GitLab DAST reports natively now.

This SARIF-to-GitLab converter has been retired. It mislabeled DAST findings as
SAST and used unstable rule ids as the vulnerability id, so GitLab could not
deduplicate findings across pipelines. Use the NightVision CLI's built-in command
instead, which produces a correctly categorized DAST report with a stable
per-finding fingerprint (so GitLab tracks findings across pipelines), NightVision
branding, and real scan times:

    nightvision export gitlab -s <scan-id> [--swagger-file <spec>] -o gl-dast-report.json

Upload it in .gitlab-ci.yml as a DAST report:

    artifacts:
      reports:
        dast: gl-dast-report.json

See the GitLab integration docs and the nightvision-skills ci-cd-integration
guide for the full pipeline. This stub remains only to give a clear migration
message to any pipeline still fetching this script; it does not convert anything.
"""

import sys

if __name__ == "__main__":
    sys.stderr.write(__doc__)
    sys.exit(2)
