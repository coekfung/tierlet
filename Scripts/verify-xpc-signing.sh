#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 /path/to/Tierlet.app" >&2
    exit 64
fi

app_bundle=$1
helper="$app_bundle/Contents/Resources/tierletd"
app_identifier="wang.coekfung.tierlet"
helper_identifier="wang.coekfung.tierlet.daemon"

if [ ! -d "$app_bundle" ] || [ ! -x "$helper" ]; then
    echo "expected a Tierlet.app bundle containing Contents/Resources/tierletd" >&2
    exit 66
fi

team_identifier=$(
    /usr/bin/codesign -dvv "$app_bundle" 2>&1 \
        | /usr/bin/sed -n 's/^TeamIdentifier=//p'
)

if [ -z "$team_identifier" ] || [ "$team_identifier" = "not set" ]; then
    echo "the app bundle has no Apple Developer Team ID" >&2
    exit 65
fi

app_requirement="anchor apple generic and identifier \"$app_identifier\" and certificate leaf[subject.OU] = \"$team_identifier\""
helper_requirement="anchor apple generic and identifier \"$helper_identifier\" and certificate leaf[subject.OU] = \"$team_identifier\""

/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_bundle"

# The client must accept only the signed helper.
/usr/bin/codesign -R="$helper_requirement" --verify --verbose=2 "$helper"
if /usr/bin/codesign -R="$helper_requirement" --verify "$app_bundle" >/dev/null 2>&1; then
    echo "the app unexpectedly satisfies the helper requirement" >&2
    exit 1
fi

# The daemon must accept only the signed app.
/usr/bin/codesign -R="$app_requirement" --verify --verbose=2 "$app_bundle"
if /usr/bin/codesign -R="$app_requirement" --verify "$helper" >/dev/null 2>&1; then
    echo "the helper unexpectedly satisfies the app requirement" >&2
    exit 1
fi

echo "Verified bidirectional XPC signing requirements for team $team_identifier."
