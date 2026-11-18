# Releasing

One tag publishes all four SDKs at the same version. Tags are plain semver (`1.2.0`,
`1.2.0-rc.1`), because Swift Package Manager only resolves those.

## Steps

1. **Pick the version** and write it to `VERSION`, then sync it everywhere:

   ```sh
   echo 1.2.0 > VERSION
   node scripts/sync-version.mjs
   ```

2. **Add a changelog entry** at the top of `flutter/CHANGELOG.md` for that version. pub.dev
   rejects a package whose changelog doesn't mention it.

3. **Open a pull request**, get it reviewed and merge it to `main` once CI passes.

4. **Tag the merge commit and push the tag:**

   ```sh
   git checkout main && git pull
   git tag 1.2.0
   git push origin 1.2.0
   ```

5. **Watch the Release workflow** (Actions → Release). It takes 20–40 minutes, mostly waiting
   for Maven Central.

## What the Release workflow does

| Job | Publishes | Notes |
|---|---|---|
| `verify` | — | Fails if the tag doesn't match `VERSION` or any package version differs. |
| `tests` | — | Runs the full CI suite for every platform. |
| `maven` | `ai.getangler:analytics` to Maven Central | Signs, uploads and releases, then waits until the artifact can be downloaded, because the wrappers' Android side depends on it. |
| `npm` | `@anglerai/react-native-analytics` to npm | With provenance. |
| `pub` | `angler_analytics` to pub.dev | Runs only when the repo variable `PUBLISH_PUB_DEV` is `true`. |
| `github-release` | GitHub release with generated notes | |
| (none) | Swift Package Manager | Nothing to publish: SPM resolves the tag. |

A version with a hyphen (`1.2.0-rc.1`) is a prerelease: npm publishes it under the `next`
dist-tag, and the GitHub release is marked as a prerelease.

**Re-running is safe.** Each publish job checks whether its registry already has the version
and skips it if so. If a release fails partway, fix the cause and re-run the failed jobs.
Maven Central and npm never allow re-publishing a version, so if a published artifact is
wrong, release a new version.

## One-time setup

What each registry needs before the workflow can publish to it. Kept here for reference and
for rotating credentials.

| Registry | Setup |
|---|---|
| Maven Central | Namespace `ai.getangler` verified on [central.sonatype.com](https://central.sonatype.com). The `release` environment holds `MAVEN_CENTRAL_USERNAME` and `MAVEN_CENTRAL_PASSWORD` (a portal user token), plus `SIGNING_IN_MEMORY_KEY` and `SIGNING_IN_MEMORY_KEY_PASSWORD` (an ASCII-armored GPG key whose public key is on keyserver.ubuntu.com). |
| npm | Org `anglerai`. The package's trusted publisher is GitHub Actions, repo `angler-ai/angler-mobile-sdk`, workflow `release.yml`, environment `release`, so no token is stored. |
| pub.dev | Package owned by the verified publisher `getangler.ai`, with automated publishing from GitHub Actions: repo `angler-ai/angler-mobile-sdk`, tag pattern `{{version}}`, environment `release`. |

**Rotating the signing key:** generate a new key, upload its public key to
keyserver.ubuntu.com, and replace the two `SIGNING_IN_MEMORY_*` secrets. Artifacts already
published keep their old signatures.
