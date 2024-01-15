#!/bin/bash
set -o errexit -o pipefail -o nounset
BUILDDIR="$(mktemp -d)"
trap 'rm -rf "$BUILDDIR"' INT TERM
for TESTFILE; do
  printf 'Testfile %s\n' "$TESTFILE"
  for FORMAT in templates/*/; do
    printf '  Format %s\n' "$FORMAT"
    for TEMPLATE in "${FORMAT}"*.tex.m4; do
      printf '    Template %s\n' "$TEMPLATE"
      m4 -DTEST_FILENAME=test.tex <"$FORMAT"/COMMANDS.m4 |
      (while read -r COMMAND; do
        printf '      Command %s\n' "$COMMAND"

        # Set up the testing directory.
        cp support/* "$TESTFILE" "$BUILDDIR"
        cd "$BUILDDIR"
        sed -r '/^\s*<<<\s*$/{x;q}' \
          <"${TESTFILE##*/}" >test-setup.tex
        sed -rn '/^\s*<<<\s*$/,/^\s*>>>\s*$/{/^\s*(<<<|>>>)\s*$/!p}' \
          <"${TESTFILE##*/}" >test-input.md
        sed -n '/^\s*>>>\s*$/,${/^\s*>>>\s*$/!p}' \
          <"${TESTFILE##*/}" >test-expected.log
        m4 -DTEST_SETUP_FILENAME=test-setup.tex \
           -DTEST_INPUT_FILENAME=test-input.md <"$OLDPWD"/"$TEMPLATE" >test.tex

        # Run the test, filter the output and concatenate adjacent lines.
        eval "$COMMAND" >/dev/null 2>&1 ||
          printf '        Command terminated with exit code %d.\n' $?
        touch test.log
        sed -nr '/^\s*TEST INPUT BEGIN\s*$/,/^\s*TEST INPUT END\s*$/{
          /^\s*TEST INPUT (BEGIN|END)\s*$/!H
          /^\s*TEST INPUT END\s*$/{s/.*//;x;s/\n//g;p}
        }' <test.log >test-actual.log

        # Compare the expected outcome against the actual outcome.
        diff -a -c test-expected.log test-actual.log ||
        # Uncomment the below lines to update the testfile.
#          (sed -n '1,/^\s*>>>\s*$/p' <"${TESTFILE##*/}" &&
#           cat test-actual.log) >"$OLDPWD"/"$TESTFILE" ||
           false

        # Clean up the testing directory.
        cd "$OLDPWD"
        find "$BUILDDIR" -mindepth 1 -exec rm -rf {} +
      done)
    done
  done
done
rm -rf "$BUILDDIR"