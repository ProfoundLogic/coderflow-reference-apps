#!/usr/bin/env bash
#
# Reference Deploy Profile — PHP + Vue
# WHAT THIS SHOWS
#   How a CoderFlow Deploy Profile runs: in a container built from THIS
#   environment's image, with the repo cloned into /workspace, receiving each
#   profile parameter as an environment variable (TARGET, DRY_RUN, RELEASE_NOTES).
#
# WHAT IT REALLY DOES
#   Builds a genuine, deployable release artifact from the cloned source: the
#   Vue front end (static build) plus the PHP API
#   (source files (runs as-is)), assembled into release.tgz.
#
# WHAT IT DELIBERATELY DOES NOT DO
#   It does not push anywhere. A hello-world has no real QA/Prod host or
#   credentials, so the upload is a clearly-labelled placeholder (see the end).
#   To make it a real deploy: add the target host + an SSH key as environment
#   Secrets (available_for: ["deploy"]) and fill in the marked block.
set -euo pipefail

APP_DIR="/workspace/coderflow-reference-apps/php-vue"
TARGET="${TARGET:-qa}"
DRY_RUN="${DRY_RUN:-true}"

echo "=================================================="
echo " CoderFlow reference deploy — PHP + Vue"
echo "   Target:   ${TARGET}"
echo "   Dry run:  ${DRY_RUN}"
echo "=================================================="

cd "${APP_DIR}"

echo
echo "==> [1/3] Building the Vue front end (static build)..."
( cd web && npm ci --no-audit --no-fund && npm run build )

echo
echo "==> [2/3] Preparing the PHP API (source files (runs as-is))..."
(
  cd api
  echo '    (PHP runs from source - nothing to build)'
)

echo
echo "==> [3/3] Assembling the release bundle..."
rm -rf release release.tgz
mkdir -p release/api
cp -R api/. release/api/
cp -R web/dist release/web
if [ -n "${RELEASE_NOTES:-}" ]; then
  printf '%s\n' "${RELEASE_NOTES}" > release/RELEASE_NOTES.txt
fi
tar -czf release.tgz -C release .
echo "    Built release.tgz:"
ls -lh release.tgz
echo "    Bundle layout:"
( cd release && find . -maxdepth 2 -type d | sort )
echo "    On the target, the API would start with: php -S 0.0.0.0:3001 router.php"

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
    #     'cd /var/www/app && tar -xzf release.tgz && systemctl restart app'

PLACEHOLDER
echo "--------------------------------------------------"
echo "Done."
