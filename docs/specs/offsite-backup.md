# Off-site backup

**Status:** draft

A second copy of the restic repository off this machine, so a stolen or burnt laptop does not take the backups with it.

## Goal

The nightly repository lives on the 990 PRO in the same laptop as the data, so it survives the system disk dying but not theft, fire or loss.
Done when a restore of `data/` succeeds from the off-site copy alone, on another machine.

## Scope

- In: an S3-compatible bucket (Backblaze B2 by default), a `restic copy` step after the nightly run, ntfy on failure, a rehearsed remote restore.
- Out: backing up media; replacing the local repository.

## Design

- Keep the local run unchanged so it stays fast and independent of the network.
- Add `homelab-backup-offsite.service` and `.timer` that run `restic copy` from `/srv/backup/restic` to the bucket (`--repo2` / `--from-repo`), after the local job.
- Credentials (`B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`, bucket URL) go in `/etc/homelab-backup.env`, mode 600; the off-site repo gets its own password file, also recorded outside the machine.
- Retention on the remote: the same `forget` policy, run by the off-site unit.
- At ~200 MB the bucket costs cents a month.
- See [Backup](../backup.md) for the current job.

## Tasks

- [ ] Create the bucket and a key scoped to it.
- [ ] `restic init` the remote repository; record its password off-machine.
- [ ] Add the off-site script and units under `host/backup/`, with ntfy on failure and success.
- [ ] Run once by hand, then enable the timer.
- [ ] Restore `data/radarr/radarr.db` from the remote onto another machine.

## Done when

- [ ] A snapshot from last night exists in the bucket.
- [ ] A failed copy posts to ntfy.
- [ ] The remote restore rehearsal passes.
- [ ] `docs/backup.md` describes the off-site copy, this spec is deleted and removed from `roadmap.md` and `AGENTS.md`.

## Open questions

- Provider: B2 vs another S3 bucket. Default B2.

## Related

- [Backup](../backup.md)
- [Notifications](../notifications.md)
