# oci-minecraft

An Oracle Cloud **Always Free** ARM server (VM.Standard.A1.Flex, 2 OCPU / 12 GB) that
provisions itself from GitHub Actions, retrying forever until Turin has capacity,
and comes up with a Fabric + Lithium Minecraft server already running.

No Terraform or OCI CLI needed on your PC. You need a GitHub account and 20 minutes.

**Start here: [SETUP.md](SETUP.md)** - click-by-click, assumes you have never
touched Terraform.

---

## Why this instead of Cloud Shell

`nohup bash -c 'until terraform apply ...'` in Cloud Shell dies with the browser.
Cloud Shell is a disposable container, `nohup` only detaches from the terminal,
and the session is killed when it goes idle. GitHub Actions is a machine that
keeps running while your PC is off, for up to 6 hours per run, and the schedule
starts a fresh run every 6 hours.

## What gets created

| Resource | Detail | Cost |
| --- | --- | --- |
| Compute | VM.Standard.A1.Flex, 2 OCPU, 12 GB RAM, Ubuntu 24.04 arm64 | Always Free |
| Boot volume | 50 GB | inside the 200 GB Always Free allowance |
| Network | VCN 10.0.0.0/16, public subnet, internet gateway, security list (22 + 25565) | free |
| Software | Java 21, Fabric server, Lithium, systemd unit, `mc` helper | free |

Nothing here can bill you as long as you stay inside the Always Free limits and
the account stays a Free Tier account. `Destroy` deletes the boot volume too,
which is what releases the storage quota.

## How the retry works

`provision.yml` runs every 6 hours (`cron: 0 */6 * * *`) and:

1. Exits in ~1 minute if the instance already exists.
2. Creates the network once (networks are never capacity-limited).
3. Loops `terraform apply` for the instance: retries only on
   *out of host capacity* and a few genuinely transient API errors, sleeps
   60-105 s with jitter, and gives up cleanly after 5 h 20 m so the runner is
   never killed mid-apply. Any other error fails loudly instead of hiding.
4. On success, prints the IP in the job summary.

State lives in an OCI Object Storage bucket via Terraform's **native `oci`
backend** (Terraform 1.12+), so a fresh runner always knows what already exists.
Without that, every run would try to create a second VCN.

The older S3-compatible backend cannot be used: OCI answers Terraform's state
upload with `501 NotImplemented - AWS chunked encoding not supported`, and the
apply fails *after* creating the resources, leaving them orphaned. The workflow
includes a `probe/` module that writes a throwaway state object first, so that
failure mode can never orphan infrastructure again.

## Files

```
terraform/          infrastructure
  compute.tf        the instance + image lookup
  network.tf        VCN, subnet, security list, route table
  cloud-init.yaml.tftpl
probe/               1-resource module that proves the state backend is writable
scripts/
  install-minecraft.sh   Fabric + Lithium + systemd (embedded in cloud-init, re-runnable)
  provision-loop.sh      the capacity retry loop
  prepare-oci-key.ps1    base64-encodes your OCI API private key for a secret
.github/workflows/
  provision.yml     the scheduled hunter
  destroy.yml       manual teardown
```

## After it is up

```bash
# from the job summary
ssh -i ~/.ssh/oci-minecraft.key ubuntu@<IP>
mc status && mc logs
```

Uploading an existing world and backups: see [docs/commands.md](docs/commands.md).
