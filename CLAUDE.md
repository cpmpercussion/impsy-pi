# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo is **not** application code — it is an Ansible-based provisioning toolkit that converts a freshly-flashed Raspberry Pi OS Lite (64-bit, Debian Trixie) SD card into a complete IMPSY appliance. The end-product is a `.img.xz` file shipped via GitHub Releases that users flash to their own SD cards.

The upstream application being provisioned lives at https://github.com/cpmpercussion/impsy (cloned by the playbook into `~/impsy` on the target Pi).

## Common commands

Install the Ansible Galaxy role dependency once:

```sh
ansible-galaxy install -r requirements.yml
```

Run the full provisioning playbook against the Pi defined in `hosts.yml`:

```sh
ansible-playbook -i ./hosts.yml ./impsy.yml --ask-pass
# or use the wrapper, which also pins ansible_python_interpreter to the current python:
./run.sh
```

Run only a subset of the playbook using task tags (`packages`, `setup`, `startup`):

```sh
ansible-playbook -i ./hosts.yml ./impsy.yml --ask-pass --tags setup
```

The target Pi must be reachable as `pi@impsypi.local` over SSH before the playbook will run (see README §"Setting up the starting image and Raspberry Pi"). The hostname/user is hard-coded in `hosts.yml`.

## Architecture

The repo has a single working pipeline (`impsy.yml`) plus a stalled experimental one (`emulated/`):

- **`impsy.yml`** — the only playbook actually used. Targets the `impsypi` host group. Installs system packages, installs Python via the `staticdev.pyenv` Galaxy role (version pinned in the `impsy_python_version` var), installs Poetry via pipx, clones IMPSY, runs `poetry install --sync`, runs `test-mdrnn` once to warm caches, then installs and enables the two systemd units. Activates `rpi-usb-gadget` so the Pi exposes ethernet-over-USB at `10.12.194.1` post-boot.
- **`templates/impsy-run.service.j2`** and **`templates/impsy-web.service.j2`** — Jinja2-templated systemd units. They `ExecStart` shell scripts (`examples/rpi/impsy-run.sh`, `examples/rpi/impsy-web.sh`) that live inside the cloned IMPSY repo, not this one. If something looks broken at the service level, look upstream.
- **`templates/g_ether.j2`** — vestigial. The old manual USB-gadget setup (commented-out tasks at the bottom of `impsy.yml`) has been replaced by the `rpi-usb-gadget` apt package. Keep these around as fallback documentation but do not re-enable them without reason.
- **`emulated/`** — an unfinished attempt to drive everything through an emulated Pi (pi-ci) in Docker. Not wired up; the README explicitly notes this path doesn't work yet.
- **`pyproject.toml`** — Poetry env for the **controller machine** (just pins `ansible`, `docker-py`, `requests`). It is `package-mode = false`; there is nothing to build here.

## Release workflow (manual, not automated)

After the playbook succeeds, the human operator:

1. Shuts down the Pi, removes the SD card, images it to `.img` with `dd`.
2. Shrinks it with PiShrink (`monsieurborges/pishrink` Docker image) producing `.img.xz`.
3. Uploads to GitHub Releases.

There is no CI for any of this. See README §"Save SD card image and compress it" for the exact commands.

## Gotchas

- The `Poetry test run IMPSY` task (`poetry run ./start_impsy.py test-mdrnn`) is slow on a Pi — it loads TensorFlow/MDRNN models — but is intentional: it primes things so the first real boot is faster.
- Python version is pinned in `impsy.yml` (`impsy_python_version`). Bumping it requires that upstream IMPSY still supports it and that the wheels exist for `aarch64`.
- The playbook assumes a fresh image. It is not idempotent in a meaningful "re-run on a working install" sense — re-running the `Git checkout` task will pull main and may break the running services.
