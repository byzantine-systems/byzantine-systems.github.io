# Byzantine Systems

[![conventional-commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![Erlang Compatible](https://img.shields.io/badge/target-erlang-b83998)](https://www.erlang.org/)
![License](https://img.shields.io/github/license/byzantine-systems/byzantine-systems.github.io)

[![Built with Nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)
[![[Nix] Build & Test](https://github.com/byzantine-systems/byzantine-systems.github.io/actions/workflows/build.yml/badge.svg)](https://github.com/byzantine-systems/byzantine-systems.github.io/actions/workflows/build.yml)

> O sages standing in God's holy fire 
>
> As in the gold mosaic of a wall,
>
> Come from the holy fire, perne in a gyre,
>
> And be the singing-masters of my soul. [^1]
>
> [^1]: [Sailing to Byzantium](https://www.poetryfoundation.org/poems/43291/sailing-to-byzantium), William Butler Yeats.

## Development

The project uses [devenv](https://devenv.sh/) and [Nix](https://nixos.org/) for
a hermetic development environment:

```sh
nix develop
```

Or, if you are already using [direnv](https://direnv.net/):

```sh
direnv allow .
```

## Building the Blog

Posts are written in Emacs [Org-mode](https://orgmode.org/) under [org/](org/), converted to Markdown by [Pandoc](https://pandoc.org/), and rendered into a static page by [Blogatto](https://blogat.to).

```sh
# Converts .org -> .md
# Then builds the codebase
make
# Launches a dev server at http://127.0.0.1:3000 with live reload
make dev
```

The generated `blog/` and `dist/` directories are gitignored, `org/`
is the source of truth.
