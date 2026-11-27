# Hardened Hermes Docker build assets

These Dockerfiles are intended for the upstream Hermes repository at:

https://github.com/NousResearch/hermes-agent.git

They are not meant to be used from this current W/PWR repository. This workspace is a different project, and the hardened Dockerfiles here are helper assets for building the upstream Hermes agent from its own source tree.

## Why this matters

The files in this folder depend on Hermes-specific source layout and runtime files such as:

- docker/
- pm/
- hermes_constants.py
- hermes_cli/
- scripts/

Those paths are part of the Hermes repository, not this W/PWR app repo. If you want to build a custom Hermes image, clone the upstream Hermes repo and use the selected hardened Dockerfile from this folder against that repo as the build context.

## Available profiles

- Dockerfile-hardened
- Dockerfile-slim
- Dockerfile-ultra-hardened

Each file is a hardened Dockerfile variant for the upstream Hermes project.

## How to use

Run the helper script from this directory:

```bash
chmod +x build-hermes.sh
./build-hermes.sh --profile hardened --tag hermes:hardened
./build-hermes.sh --profile slim --tag hermes:slim
./build-hermes.sh --profile ultra-hardened --tag hermes:ultra
```

You can also pass the matching Dockerfile names directly:

```bash
./build-hermes.sh --profile Dockerfile-hardened --tag hermes:hardened
./build-hermes.sh --profile Dockerfile-slim --tag hermes:slim
./build-hermes.sh --profile Dockerfile-ultra-hardened --tag hermes:ultra
```

The script will:

1. Clone the upstream Hermes repo from GitHub.
2. Select the requested Dockerfile variant.
3. Build the Hermes image using that Dockerfile and the cloned Hermes repo as the build context.

## Notes

- This directory is a helper for building the upstream Hermes image only.
- The build should be run on a machine that has Docker and GitHub access.
- The Dockerfiles here are not for the W/PWR repo itself.
