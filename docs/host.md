# Host

The Arch laptop under the stack (`hvenrylab`, RTX 3070 Laptop, 8 GB): kernel, GPU driver, Docker, Tailscale and the always-on settings the containers depend on.

## Why

Containers cannot provide their own GPU driver, kernel, network or power behaviour.
A laptop also defaults to sleeping, which takes every service down with it.

## How it works

- **Kernels:** `linux` plus `linux-lts` as a fallback boot entry, with `nvidia-open-dkms` so the driver rebuilds for every installed kernel.
  A pacman hook regenerates `grub.cfg` on every kernel change, because `grub.cfg` is static and a new kernel otherwise never appears in the menu.
- **Docker:** `docker`, `docker-compose`, `docker-buildx` and `nvidia-container-toolkit`; `nvidia-ctk runtime configure --runtime=docker` writes `/etc/docker/daemon.json`.
  The user is in the `docker` group (log out and back in after adding it; a new tab is not enough).
- **Tailscale:** `tailscale up --ssh --hostname=hvenrylab`, with key expiry disabled for this machine in the admin console.
- **Always on:** `sleep`, `suspend`, `hibernate` and `hybrid-sleep` targets are masked, and `HandleLidSwitch=ignore` is set in `/etc/systemd/logind.conf`.
  Docker and Tailscale are system services and run with nobody logged in.
- **Battery:** the laptop battery is the UPS; [Power guard](powerguard.md) shuts down cleanly before it runs out.
  The charge limit is set through Razer Synapse; this machine exposes no `charge_control_end_threshold`.

Verify the GPU path end to end:

```bash
dkms status                                   # one line per installed kernel
docker run --rm --gpus all ubuntu nvidia-smi  # must print the GPU
```

## Tech

- Arch Linux, GRUB, mkinitcpio
- `nvidia-open-dkms`, NVIDIA Container Toolkit
- Docker, Tailscale

## Key files

- `/etc/pacman.d/hooks/95-grub.hook` - regenerates `grub.cfg` after kernel changes
- `/etc/docker/daemon.json` - NVIDIA runtime, written by `nvidia-ctk`
- `/etc/systemd/logind.conf` - lid switch ignored
- `host/` - systemd units and scripts installed by hand as root

## Decisions and gotchas

- `nvidia-open` (non-DKMS) ships modules for `linux` only; a second kernel then has no GPU driver, and with `nvidia-drm.modeset=1` that is a black screen, not a fallback.
- The initramfs is ~225 MB per kernel because the `kms` hook pulls in GSP firmware; the 1 GB ESP holds two kernels with little spare.
- **A driver upgrade needs a reboot.** Until then `nvidia-smi` reports `Driver/library version mismatch`; running containers keep the GPU, new ones fail to start.
- Default target is still `graphical.target`; a desktop session's idle daemon is harmless only because the sleep targets are masked.
- `upower` is installed but disabled: its critical action wants hibernate, which is masked.
- Update Arch every week or two, read the Arch news first, and reboot after kernel updates.

## Related

- [Storage](storage.md)
- [Power guard](powerguard.md)
- [Ingress](ingress.md)
