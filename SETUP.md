# SETUP - zero to a running server

Follow these in order. Every value you need is copied from the OCI Console; you
never edit code except for one optional Minecraft version.

Total time: about 20 minutes. Then you wait for capacity, hands-free.

---

## Step 1 - Put this folder on GitHub

1. Go to <https://github.com/new>.
2. Repository name: `oci-minecraft`.
3. Visibility: **Public**.

   > This matters. Public repos get unlimited free GitHub Actions minutes.
   > A private repo gets 2,000 minutes/month, and one of these hunts can burn
   > 600+ minutes a day. Nothing secret lives in the code - credentials are
   > repo secrets.

4. Do **not** tick "Add a README". Click **Create repository**.
5. Open PowerShell in this folder and run the two lines GitHub shows you under
   *"…or push an existing repository from the command line"*, which look like:

   ```powershell
   git remote add origin https://github.com/YOURNAME/oci-minecraft.git
   git branch -M main
   git push -u origin main
   ```

If `git` complains that a repo is not initialised, run `git init` first.

---

## Step 2 - Create the bucket that stores Terraform's state

1. OCI Console -> hamburger menu -> **Storage** -> **Buckets**.
2. Make sure the compartment is your root compartment, then **Create bucket**.
3. Name: `mc-terraform-state`. Storage tier: **Standard**. Leave it private.
4. After it is created, look at the **Buckets** list page header. It shows
   `Namespace: xxxxxxx`. Copy that value: it becomes the secret `OCI_NAMESPACE`.

   (It is also on the bucket's detail page, near "Namespace".)

---

## Step 3 - Create a Customer Secret Key (the bucket password)

1. Top-right profile icon -> **My profile** -> **Customer secret keys**.
2. **Generate secret key**. Name: `github-actions`.
3. A dialog shows an **access key** and a **secret key**. The secret is shown
   **once** - copy both somewhere safe now.

| Value | Secret name |
| --- | --- |
| access key | `OCI_S3_ACCESS_KEY` |
| secret key | `OCI_S3_SECRET_KEY` |

---

## Step 4 - Create the API signing key

This is a **different** key from your SSH key. SSH gets you into the server;
this one lets Terraform talk to OCI's API.

1. Profile icon -> **My profile** -> **API keys** -> **Add API key**.
2. Select **Generate API key pair**, click **Download private key**
   (saves `oci_api_key.pem`), then **Add**.
3. The console now shows a configuration preview. Copy these three values:

| Value in the preview | Secret name |
| --- | --- |
| `tenancy=` | `OCI_TENANCY_OCID` |
| `user=` | `OCI_USER_OCID` |
| `fingerprint=` | `OCI_FINGERPRINT` |

Keep the preview open until Step 5 is done.

---

## Step 5 - Base64 the private key

GitHub secrets mangle multi-line PEM files, so the key is stored base64-encoded.

```powershell
cd C:\Users\LorenPC\Documents\Test\oci-minecraft
powershell -ExecutionPolicy Bypass -File scripts\prepare-oci-key.ps1 -Pem "$HOME\Downloads\oci_api_key.pem"
```

It writes `.oci-key-b64.txt` and puts the value on your clipboard. That value
becomes the secret `OCI_PRIVATE_KEY_B64`.

Delete the file when you are done: `Remove-Item .oci-key-b64.txt`

---

## Step 6 - Add the eight repository secrets

Repo -> **Settings** -> **Secrets and variables** -> **Actions** -> **New repository secret**.

| Secret | Where it comes from |
| --- | --- |
| `OCI_TENANCY_OCID` | Step 4 preview |
| `OCI_USER_OCID` | Step 4 preview |
| `OCI_FINGERPRINT` | Step 4 preview |
| `OCI_PRIVATE_KEY_B64` | Step 5 output |
| `OCI_BUCKET` | `mc-terraform-state` (Step 2) |
| `OCI_NAMESPACE` | Step 2 |
| `OCI_S3_ACCESS_KEY` | Step 3 |
| `OCI_S3_SECRET_KEY` | Step 3 |
| `DISCORD_WEBHOOK` *(optional)* | any Discord channel webhook; leave out to skip |

Names must match exactly. The workflow refuses to run and tells you which ones
are missing.

---

## Step 7 - Run it once by hand

Repo -> **Actions** -> **Provision Minecraft server** -> **Run workflow**.

Leave the version at `1.21.4` (or type the version your world runs on - it is
only used on first boot). Press the green button.

What the run does, in order:

| Step | Meaning |
| --- | --- |
| Check required secrets | instant pass/fail |
| terraform init | downloads the OCI provider, reads state from your bucket |
| Create network | ~1 minute, always succeeds |
| Hunt for A1.Flex capacity | the long part - can run up to 5 h 20 m |
| Report result | prints the IP, or says "no capacity this window" |

A run that ends with **"No capacity in this window"** is normal and green - the
schedule keeps trying every 6 hours while your PC is off. Nothing to babysit.

When it succeeds, the run summary shows:

```
Server address   <IP>:25565
SSH              ssh -i ~/.ssh/oci-minecraft.key ubuntu@<IP>
```

---

## Step 8 - Connect over SSH

I already copied the key that works into your SSH folder as
`C:\Users\LorenPC\.ssh\oci-minecraft.key`, with permissions locked down so
Windows OpenSSH accepts it.

```powershell
ssh -i $HOME\.ssh\oci-minecraft.key ubuntu@<IP>
```

All three keys you generated are authorised on the server, so if you reach for
one of the originals it will also work.

Useful once inside:

```bash
mc status      # is the server running?
mc logs        # live log, Ctrl-C to leave
mc restart
mc backup      # stop, tar the world, start again
```

The Minecraft server installs itself on first boot (Java, Fabric, Lithium,
systemd service). If `mc status` says the unit is not running yet, give it
2-3 minutes and check the install log:

```bash
tail -f /var/log/minecraft-install.log
```

---

## Step 9 - Play

In Minecraft: **Multiplayer -> Add Server -> `<IP>:25565`**.

First launch may take a minute while it generates the world. Then upload your
existing world if you want to keep it: [commands.md](docs/commands.md).

---

## Troubleshooting

**"No capacity" every single run for days.**
Expected in a busy region. The loop is doing its job; keep the schedule on.
Oracle's own docs say the fastest fix is upgrading the tenancy to Pay As You Go -
you stay at $0 while inside the Always Free limits, but paid accounts get
priority for A1 capacity. That is a decision on your side, not something the
workflow can do.

**Red X at "Check required secrets".**
The message lists which names are missing or misspelled.

**Red X at "terraform init" with `SignatureDoesNotMatch` / `InvalidAccessKeyId`.**
`OCI_S3_ACCESS_KEY` / `OCI_S3_SECRET_KEY` are wrong or were copied with the
"access key" swapped with the "secret key". Customer Secret Key, not API key.

**Red X at init with `NoSuchBucket` or a DNS error.**
`OCI_NAMESPACE` or `OCI_BUCKET` is wrong.

**Red X at "Hunt for capacity" with `NotAuthenticated` / `NotAuthorized`.**
`OCI_FINGERPRINT` does not match `OCI_PRIVATE_KEY_B64`. Re-do Steps 4-5 and make
sure the PEM you base64'd is the one downloaded in that same step.

**Instance exists, SSH works, but Minecraft says "connection refused".**
Three things can block the port, in order: the security list (already handled by
`network.tf`), the OS firewall (handled by the install script), and the server
itself not running (`mc status`). Check the last one first.

**Actions stopped running the schedule.**
GitHub disables schedules on public repos after 60 days without a commit. Push
any trivial commit, or press **Run workflow**.

**I want it gone.**
Actions -> **Destroy Minecraft server** -> type `destroy-minecraft`.
This deletes the instance **and its boot volume**, so the world goes with it.
Run `mc backup` and copy it off first.
