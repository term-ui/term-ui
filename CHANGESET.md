# Using Changesets in this Monorepo

This repository uses [changesets](https://github.com/changesets/changesets) for versioning and publishing packages to npm.

## Adding a Changeset

When you've made changes to the codebase that you want to release, you need to add a changeset:

```bash
pnpm changeset
```

This will prompt you to:
1. Select which packages have changed
2. Choose the type of version bump for each package (major, minor, patch)
3. Write a summary of the changes

The changeset will be added to the `.changeset` directory as a markdown file.

## Versioning Packages

To bump the versions of all packages with changesets:

```bash
pnpm version
```

This command will:
1. Consume all changesets
2. Update package versions
3. Update internal dependencies
4. Generate/update changelogs

## Publishing Packages

To publish packages to npm:

```bash
pnpm publish
```

This will:
1. Build all packages
2. Publish packages that have been versioned

## Automated Releases

When PRs with changesets are merged to the main branch, the GitHub Actions workflow will automatically:
1. Create a PR with the version changes if there are any changesets
2. Publish to npm when that PR is merged

## Notes

- The `docs` package is configured to be ignored in changesets
- All packages under the `examples/` directory are ignored and won't be published
- Only packages under `packages/*` are published to npm (excluding `docs`)
- All packages are published with public access 