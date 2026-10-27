# Commands: SSH, world upload, backups

Replace `<IP>` with the address from the Actions job summary.

## Set up an SSH alias once (optional but nice)

`C:\Users\LorenPC\.ssh\config`:

```
Host mc
  HostName <IP>
  User ubuntu
  IdentityFile ~/.ssh/oci-minecraft.key
```

Then `ssh mc` works, and so does `scp file mc:/tmp/`.

## Upload your existing world

Stop the server, replace the world, start it again. Uploading to `/tmp` first
avoids half-written chunks if the connection drops.

```powershell
# 1. stop the server
ssh -i $HOME\.ssh\oci-minecraft.key ubuntu@<IP> "sudo systemctl stop minecraft"

# 2. upload (from the folder that contains your world folder)
scp -i $HOME\.ssh\oci-minecraft.key -r .\world ubuntu@<IP>:/tmp/world

# 3. swap it in, fix ownership, start
ssh -i $HOME\.ssh\oci-minecraft.key ubuntu@<IP> @"
sudo rm -rf /opt/minecraft/world_old
sudo mv /opt/minecraft/world /opt/minecraft/world_old
sudo mv /tmp/world /opt/minecraft/world
sudo chown -R minecraft:minecraft /opt/minecraft/world
sudo systemctl start minecraft
"@
```

Your old world stays at `/opt/minecraft/world_old` until you delete it, so a
mistake is recoverable.

## Backups

```bash
mc backup        # stops the server, tars world/, starts it again
```

Backups land in `/opt/minecraft/backups/`. Pull one down:

```powershell
scp -i $HOME\.ssh\oci-minecraft.key ubuntu@<IP>:/opt/minecraft/backups/world-*.tar.gz .
```

The boot volume is 50 GB and the world is usually a few GB, so keep only the
last handful:

```bash
ssh ubuntu@<IP> "ls -t /opt/minecraft/backups/*.tar.gz | tail -n +6 | xargs -r rm"
```

## Changing the Minecraft version

The version is baked in at first boot only. To change it later:

```bash
sudo systemctl stop minecraft
sudo sed -i 's/^MC_VERSION=.*/MC_VERSION="1.21.5"/' /etc/minecraft-bootstrap.env
sudo rm /opt/minecraft/fabric-server-launch.jar
sudo bash /tmp/install-minecraft.sh
```

Take a backup first - a version downgrade can corrupt a world.

## Logs

```bash
sudo journalctl -u minecraft -f          # live
sudo journalctl -u minecraft -n 200      # last 200 lines
tail -f /var/log/minecraft-install.log   # first-boot installer
```
