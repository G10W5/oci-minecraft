#!/usr/bin/env bash
# Installs an always-on, systemd-managed Fabric server on this machine.
# Safe to re-run: anything already installed is left alone.
#
# Called automatically by cloud-init on first boot, and manually after editing
# the config:
#   sudo bash /tmp/install-minecraft.sh
set -euo pipefail

[ -f /etc/minecraft-bootstrap.env ] && . /etc/minecraft-bootstrap.env

MC_VERSION="${MC_VERSION:-1.21.4}"
MC_PORT="${MC_PORT:-25565}"
MC_XMS="${MC_XMS:-2G}"
MC_XMX="${MC_XMX:-10G}"
MC_DIR="${MC_DIR:-/opt/minecraft}"
MC_USER="${MC_USER:-minecraft}"
FABRIC_INSTALLER_VERSION="${FABRIC_INSTALLER_VERSION:-1.0.1}"
# The Fabric loader build for that Minecraft version; auto-resolved if left empty.
FABRIC_LOADER_VERSION="${FABRIC_LOADER_VERSION:-}"
INSTALL_LITHIUM="${INSTALL_LITHIUM:-1}"

log() { printf '[minecraft-install] %s\n' "$*"; }
die() { printf '[minecraft-install] ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run me with sudo"

export DEBIAN_FRONTEND=noninteractive

log "Java"
if ! java -version 2>&1 | grep -q 'version "2[1-9]'; then
  apt-get update -y
  apt-get install -y openjdk-21-jre-headless
fi
apt-get install -y --no-install-recommends curl jq rsync ca-certificates

log "User and directories"
if ! id -u "$MC_USER" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "$MC_DIR" --shell /usr/sbin/nologin "$MC_USER"
fi
mkdir -p "$MC_DIR"/{logs,mods,config,backups}

log "Firewall (OCI images reject everything except port 22 by default)"
mkdir -p /etc/iptables
iptables -C INPUT -p tcp --dport "$MC_PORT" -j ACCEPT 2>/dev/null \
  || iptables -I INPUT 1 -p tcp --dport "$MC_PORT" -j ACCEPT
if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save || true
fi
iptables-save > /etc/iptables/rules.v4 || true

log "Fabric server for Minecraft $MC_VERSION"
if [ ! -f "$MC_DIR/fabric-server-launch.jar" ]; then
  installer="/tmp/fabric-installer-${FABRIC_INSTALLER_VERSION}.jar"
  curl -fsSL -o "$installer" \
    "https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FABRIC_INSTALLER_VERSION}/fabric-installer-${FABRIC_INSTALLER_VERSION}.jar"

  loader_args=()
  if [ -n "$FABRIC_LOADER_VERSION" ]; then
    loader_args=(-loader "$FABRIC_LOADER_VERSION")
  fi

  ( cd "$MC_DIR" && java -jar "$installer" server \
      -mcversion "$MC_VERSION" "${loader_args[@]}" -downloadMinecraft -dir "$MC_DIR" )
else
  log "Fabric already installed, skipping"
fi

if [ "$INSTALL_LITHIUM" = "1" ] && ! compgen -G "$MC_DIR/mods/lithium*.jar" >/dev/null; then
  log "Lithium (fabric, $MC_VERSION)"
  api="https://api.modrinth.com/v2/project/lithium/version?loaders=%5B%22fabric%22%5D&game_versions=%5B%22${MC_VERSION}%22%5D"
  url="$(curl -fsSL --retry 3 "$api" | jq -r '.[0].files[0].url // empty' || true)"
  if [ -n "$url" ]; then
    curl -fsSL -o "$MC_DIR/mods/lithium.jar" "$url"
  else
    log "No Lithium build for $MC_VERSION yet - continuing without it"
  fi
fi

log "Config"
[ -f "$MC_DIR/eula.txt" ] || printf 'eula=true\n' > "$MC_DIR/eula.txt"
if [ ! -f "$MC_DIR/server.properties" ]; then
  cat > "$MC_DIR/server.properties" <<PROPS
server-port=${MC_PORT}
motd=\u00a7aOCI Ampere server
max-players=20
view-distance=10
simulation-distance=10
online-mode=true
enable-status=true
spawn-protection=0
sync-chunk-writes=false
white-list=false
PROPS
fi

cat > /etc/systemd/system/minecraft.service <<UNIT
[Unit]
Description=Minecraft Fabric server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${MC_USER}
WorkingDirectory=${MC_DIR}
ExecStart=/usr/bin/java -Xms${MC_XMS} -Xmx${MC_XMX} \\
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=130 \\
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC \\
  -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M \\
  -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 \\
  -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 \\
  -XX:SurvivorRatio=32 -XX:MaxTenuringThreshold=1 \\
  -jar ${MC_DIR}/fabric-server-launch.jar nogui
Restart=on-failure
RestartSec=15
SuccessExitStatus=0 143
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT

cat > /usr/local/bin/mc <<'HELPER'
#!/usr/bin/env bash
# mc <start|stop|restart|status|logs|console|backup>
set -euo pipefail
case "${1:-status}" in
  start)   sudo systemctl start minecraft ;;
  stop)    sudo systemctl stop minecraft ;;
  restart) sudo systemctl restart minecraft ;;
  status)  systemctl status minecraft --no-pager ;;
  logs)    sudo journalctl -u minecraft -f --no-pager ;;
  console) sudo -u minecraft screen -r minecraft 2>/dev/null || echo "run: sudo journalctl -u minecraft -f" ;;
  backup)
    ts="$(date +%Y%m%d-%H%M%S)"
    sudo systemctl stop minecraft
    sudo tar -C /opt/minecraft -czf "/opt/minecraft/backups/world-${ts}.tar.gz" world
    sudo systemctl start minecraft
    echo "backup written to /opt/minecraft/backups/world-${ts}.tar.gz"
    ;;
  *) echo "usage: mc <start|stop|restart|status|logs|backup>" >&2; exit 1 ;;
esac
HELPER
chmod 0755 /usr/local/bin/mc

chown -R "$MC_USER":"$MC_USER" "$MC_DIR"

log "Starting service"
systemctl daemon-reload
systemctl enable --now minecraft.service
sleep 5
systemctl --no-pager --lines=15 status minecraft.service || true

log "Done. Logs: journalctl -u minecraft -f"
