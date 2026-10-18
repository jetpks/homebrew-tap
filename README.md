# jetpks/homebrew-tap

Homebrew tap for the jetpks Ruby CLIs.

## How do I install these formulae?

`brew install jetpks/tap/<formula>`

Or `brew tap jetpks/tap` and then `brew install <formula>`.

Or, in a `brew bundle` `Brewfile`:

```ruby
tap "jetpks/tap"
brew "<formula>"
```

## Available formulae

| formula | tool | description |
|---|---|---|
| `jetpks/tap/space-cadet` | `space` | Task-scoped project workspaces (repos · notes · artifacts under one root) |
| `jetpks/tap/space-architect` | `architect` | Architect Loop: structured judgment-and-build cycles for humans and AI builders |
| `jetpks/tap/repo-tender` | `repo-tender`, `src` | Keep your local git clones forever evergreen — clean, on default branch, fetched |

## Install

```sh
brew tap jetpks/tap
brew install jetpks/tap/space-cadet
brew install jetpks/tap/space-architect
brew install jetpks/tap/repo-tender
```

Each formula installs the released Ruby gem from rubygems.org into its own
`libexec` gem tree and wraps every gem executable with an env script pinning
PATH to Homebrew's Ruby — no system Ruby, `mise`, or `rbenv` setup required.

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).
