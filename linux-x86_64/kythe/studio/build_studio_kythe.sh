#!/bin/bash -e

# Bazel build target for running kythe extractor as an extra_action
# to create kythe index files as a side effect of running the build.
EAL=//prebuilts/tools/linux-x86_64/kythe/extractors:extract_kindex

# Path to the kyth binaries.
KYTHE_ROOT="$(readlink -f prebuilts/tools/linux-x86_64/kythe)"

# Get the output path for the kythe artifacts.
OUT="$1"
if [ -z "${OUT}" ]; then
  echo Usage: $0 \<out_dir\> [gcs_bucket]
  echo  e.g. $0 $HOME/studio_kythe
  echo
  echo $0 must be launched from the root of the studio branch.
  exit 1
fi
OUT_ENTRIES="${OUT}/entries"
mkdir -p "${OUT_ENTRIES}"

TARGETS="$(cat tools/base/bazel/build_targets)"

# Build all targets and run the kythe extractor via extra_actions.
bazel build \
  --experimental_action_listener=${EAL} -- ${TARGETS}

# Find all generated kythe index files.
KINDEXES=$(find bazel-out/local-fastbuild/extra_actions/ \
  -name *.kindex -exec realpath {} \;)

# For each kythe index file run the java index to generate kythe
# entries.
cd "${OUT_ENTRIES}"
for KINDEX in ${KINDEXES}; do
  ENTRIES="$(basename "${KINDEX}").entries"
  if [ ! -f "${ENTRIES}" ]; then
    java -jar "${KYTHE_ROOT}/indexers/java_indexer.jar" \
      "${KINDEX}" > "${ENTRIES}"
  fi
done;

GSBUCKET="$2"
if [ -n "${GSBUCKET}" ]; then
  TIMESTAMP=$(date +'%s')
  gsutil -m cp "${OUT_ENTRIES}/*" "${GSBUCKET}/${TIMESTAMP}/"
fi