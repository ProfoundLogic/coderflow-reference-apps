#!/usr/bin/env bash
#
# Reference Deploy Profile — static site (HTML/CSS/JS)
# WHAT THIS SHOWS
#   How a CoderFlow Deploy Profile runs: in a container built from THIS
#   environment's image, with the repo cloned into /workspace, receiving each
#   profile parameter as an environment variable (TARGET, DRY_RUN, RELEASE_NOTES).
#
# WHAT IT REALLY DOES
#   Packages this app's deployable files into release.tgz.
#
# WHAT IT DELIBERATELY DOES NOT DO
#   It does not push anywhere. This reference environment has no real QA/Prod host
#   or credentials, so the upload is a clearly-labelled placeholder. To make it
#   real, add the host + an SSH key as environment Secrets (available_for:
#   ["deploy"]) and fill in the marked block.
set -euo pipefail

APP_DIR="/workspace/coderflow-reference-apps/static"
TARGET="${TARGET:-qa}"
DRY_RUN="${DRY_RUN:-true}"

echo "=================================================="
echo " CoderFlow reference deploy — static site (HTML/CSS/JS)"
echo "   Target:   ${TARGET}"
echo "   Dry run:  ${DRY_RUN}"
echo "=================================================="

cd "${APP_DIR}"

echo
echo "==> [1/2] Assembling the release bundle (static site (HTML/CSS/JS))..."
rm -rf release release.tgz
mkdir -p release
for f in *; do
  case "$f" in
    environment.json|AGENTS.md|README.md|deployment-profiles|release|release.tgz) continue ;;
  esac
  cp -R "$f" release/
done
if [ -n "${RELEASE_NOTES:-}" ]; then
  printf '%s\n' "${RELEASE_NOTES}" > release/RELEASE_NOTES.txt
fi
tar -czf release.tgz -C release .
echo "    Built release.tgz:"
ls -lh release.tgz
echo "    On the target, serve it with: python3 -m http.server 8000 --bind 0.0.0.0"

echo
echo "--------------------------------------------------"
if [ "${DRY_RUN}" = "true" ]; then
  echo " DRY RUN — release built, upload to '${TARGET}' skipped."
  echo " A real deploy would now run the command below."
else
  echo " DEPLOY to '${TARGET}' — placeholder: this reference environment has no"
  echo " host configured, so there is nothing to upload to. The command a real"
  echo " deploy would run:"
fi
cat <<'PLACEHOLDER'

    # Ship release.tgz to the target host over SSH. Provide DEPLOY_HOST, DEPLOY_USER,
    # and an SSH key as environment Secrets (available_for: ["deploy"]), then
    # replace this block with:
    #
    #   scp release.tgz "${DEPLOY_USER}@${DEPLOY_HOST}:/var/www/app/"
    #   ssh "${DEPLOY_USER}@${DEPLOY_HOST}" \
    #     'cd /var/www/app && tar -xzf release.tgz'

PLACEHOLDER
echo "--------------------------------------------------"
echo "Done."
