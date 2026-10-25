#!/bin/zsh
# Prepare a version commit and push its release tag only after that commit passes CI.
set -euo pipefail
cd "${0:A:h:h}"

fail() { print -u2 -- "$1"; exit 1; }
[[ $# == 1 ]] || fail 'Usage: scripts/release.zsh major.minor.patch'
version=$1
[[ "$version" =~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' ]] || fail 'Invalid version.'
[[ "$(git symbolic-ref --quiet --short HEAD)" == main ]] || fail 'Switch to main first.'
[[ -z "$(git status --porcelain)" ]] || fail 'Commit or stash your changes first.'
command -v gh >/dev/null || fail 'Install GitHub CLI (gh) first.'

origin_url=$(git remote get-url origin)
case "$origin_url" in
git@github.com:*) repository=${origin_url#git@github.com:} ;;
https://github.com/*) repository=${origin_url#https://github.com/} ;;
*) fail 'origin must be a GitHub repository (SSH or HTTPS).' ;;
esac
repository=${repository%.git}
gh auth status --hostname github.com
tag="v$version"
[[ -z "$(git ls-remote origin "refs/tags/$tag")" ]] || fail "Remote tag $tag already exists."
git fetch origin main
git merge-base --is-ancestor FETCH_HEAD HEAD || fail 'Update main from origin before releasing.'

current=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
if [[ "$version" != "$current" ]]; then
	autoload -Uz is-at-least
	if is-at-least "$version" "$current"; then fail "Version must be newer than $current."; fi
	git show-ref --verify --quiet "refs/tags/$tag" && fail "Local tag $tag already exists."
	build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Info.plist)
	[[ "$build" =~ '^[0-9]+$' ]] || fail 'CFBundleVersion must be an integer.'
	temporary=$(mktemp .release-plist.XXXXXX)
	trap '[[ -z "$temporary" ]] || rm -f -- "$temporary"' EXIT
	cp -p Info.plist "$temporary"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$temporary"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $((10#$build + 1))" "$temporary"
	mv "$temporary" Info.plist
	temporary=''
	git add -- Info.plist
	git commit -m "chore: release $version"
fi

commit=$(git rev-parse HEAD)
if git show-ref --verify --quiet "refs/tags/$tag"; then
	[[ "$(git rev-parse "$tag^{commit}")" == "$commit" ]] || fail "Local tag $tag points to another commit."
fi
git push origin HEAD:refs/heads/main
print "Waiting for CI on $commit..."
run_id=''
for attempt in {1..30}; do
	run_id=$(gh run list --repo "$repository" --workflow ci.yml --branch main --event push \
		--commit "$commit" --limit 1 --json databaseId --jq '.[0].databaseId // empty')
	[[ -z "$run_id" ]] || break
	sleep 2
done
[[ -n "$run_id" ]] || fail "CI did not appear. Retry: scripts/release.zsh $version"
gh run watch "$run_id" --repo "$repository" --exit-status --interval 10 ||
	fail "CI failed. No tag was pushed. Fix the failure and retry: scripts/release.zsh $version"
[[ "$(gh run view "$run_id" --repo "$repository" --json conclusion --jq .conclusion)" == success ]] ||
	fail 'CI did not succeed. No tag was pushed.'

[[ "$(git symbolic-ref --quiet --short HEAD)" == main && "$(git rev-parse HEAD)" == "$commit" &&
	-z "$(git status --porcelain)" ]] || fail 'The checkout changed while CI was running. No tag was pushed.'
remote_commit=$(git ls-remote origin refs/heads/main)
[[ "${remote_commit%%$'\t'*}" == "$commit" ]] || fail 'Remote main changed during CI. No tag was pushed.'
if git show-ref --verify --quiet "refs/tags/$tag"; then
	[[ "$(git rev-parse "$tag^{commit}")" == "$commit" ]] || fail "Local tag $tag changed during CI."
else
	git tag -a "$tag" "$commit" -m "Btop Desktop $version"
fi
git push origin "refs/tags/$tag"
print "Tag $tag pushed. Follow draft preparation:"
print "https://github.com/$repository/actions/workflows/release.yml"
