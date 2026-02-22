#!/usr/bin/env bash
set -x
set -e

resultdir="${COPR_RESULTDIR}"
git clone "https://github.com/${COPR_OWNER}/${COPR_PACKAGE}.git" --depth 1
cd "${COPR_PACKAGE}"

# get info from the webhook payload
if [[ -z "$REVISION" ]]; then
  # the hook_payload file contains webhook JSON payload (copr creates it for us);
  # it is created only if the build is triggered by Custom webhook.
  if [[ -f "$resultdir"/hook_payload ]]; then
    git clone https://github.com/praiskup/copr-ci-tooling \
      "$resultdir/cct" --depth 1
    export PATH="$resultdir/cct:$PATH"

    echo "---"
    cat "$resultdir"/hook_payload
    echo "---"

    # use jq to get the pr_id from the hook_payload
    PR=$(jq -r '.pr_id // empty' "$resultdir"/hook_payload)
    if [[ -z "$PR" ]]; then
      BRANCH="master"
    else
      BRANCH="pr/${PR}"
    fi

    copr-travis-checkout "$resultdir"/hook_payload
  fi
else
  git checkout "$REVISION"
fi

# read optional exclusions from .copr-ci config file
# each non-empty, non-comment line is treated as a submodule path or directory
# to exclude (relative to the repo root, e.g. "third-party/build-deps")
EXCLUDED_PATHS=()
if [[ -f ".copr-ci" ]]; then
  echo "Found .copr-ci config file, reading exclusions..."
  while IFS= read -r line || [[ -n "$line" ]]; do
    # skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    EXCLUDED_PATHS+=("$line")
    echo "  Excluding: $line"
  done < ".copr-ci"
fi

# initialize the submodules, skipping any excluded paths
if [[ ${#EXCLUDED_PATHS[@]} -gt 0 ]]; then
  # get all top-level submodule paths, then init only the ones not excluded
  mapfile -t TOP_SUBMODULES < <(git submodule status | awk '{print $2}')

  for submodule in "${TOP_SUBMODULES[@]}"; do
    skip=false
    for excluded in "${EXCLUDED_PATHS[@]}"; do
      # match exact path or any path that starts with the excluded prefix
      if [[ "$submodule" == "$excluded" || "$submodule" == "$excluded/"* ]]; then
        skip=true
        break
      fi
    done
    if [[ "$skip" == false ]]; then
      git submodule update --init --recursive --depth 1 -- "$submodule"
    else
      echo "Skipping submodule: $submodule"
    fi
  done
else
  git submodule update --init --recursive --depth 1
fi

# get the tag of this commit IF it has one
TAG=$(git tag --points-at HEAD | head -n1)
if [[ -z "$TAG" ]]; then
  TAG="0.0.$PR"
fi
TAG="${TAG#v}"  # remove v prefix from the tag
echo "TAG=$TAG"

# get the commit
COMMIT=$(git rev-parse HEAD)
echo "COMMIT=$COMMIT"

# move spec file to the correct location
directories=(
  "."
  "./packaging/linux/copr"
)
for dir in "${directories[@]}"; do
  if [[ -f "${dir}/${COPR_PACKAGE}.spec" ]]; then
    echo "Found spec file in ${dir}"
    rpmlint "${dir}/${COPR_PACKAGE}.spec"

    mv "${dir}/${COPR_PACKAGE}.spec" "${resultdir}"
    break
  fi
done

# fail if the spec file is not in the resultdir
if [[ ! -f "${resultdir}/${COPR_PACKAGE}.spec" ]]; then
  echo "ERROR: ${COPR_PACKAGE}.spec not found" >&2
  exit 1
fi

# use sed to replace these values in the spec file
sed -i "s|%global build_version 0|%global build_version ${TAG}|" "${resultdir}"/*.spec
sed -i "s|%global branch 0|%global branch ${BRANCH}|" "${resultdir}"/*.spec
sed -i "s|%global commit 0|%global commit ${COMMIT}|" "${resultdir}"/*.spec

# create a tarball of the source code, excluding any configured paths
TAR_EXCLUDE_ARGS=()
for path in "${EXCLUDED_PATHS[@]}"; do
  TAR_EXCLUDE_ARGS+=("--exclude=./${path}")
done
tar -czf "${resultdir}/tarball.tar.gz" "${TAR_EXCLUDE_ARGS[@]}" .
