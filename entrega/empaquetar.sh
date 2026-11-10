#!/usr/bin/env bash
# Arma el archivo de entrega de un TP: grabaciones, capturas .pcap, configuraciones, estado final de la red y respuestas.
#
#   Uso:  sudo bash empaquetar.sh TP3 apellido      (con sudo o como root lee configuraciones y el ruleset)
#
# Genera ~/entrega-TP3-apellido-<vm>.tar.gz. En TP1 y TP2 corrélo en cada VM que usaste (sale un archivo por VM).
# Nunca se corta por un error: si un comando no existe o falla, lo anota y sigue. No modifica nada del sistema.

TP=$(printf '%s' "${1:-}" | tr '[:lower:]' '[:upper:]')
APE=$(printf '%s' "${2:-}" | sed 's/á/a/g; s/à/a/g; s/ä/a/g; s/Á/a/g; s/é/e/g; s/è/e/g; s/ë/e/g; s/É/e/g;
      s/í/i/g; s/ï/i/g; s/Í/i/g; s/ó/o/g; s/ò/o/g; s/ö/o/g; s/Ó/o/g; s/ú/u/g; s/ü/u/g; s/Ú/u/g; s/Ü/u/g;
      s/ñ/n/g; s/Ñ/n/g' | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
case "$TP" in TP1|TP2|TP3|TP4|TP5|TP6|TP7|MK) ;; *) TP= ;; esac
if [ -z "$TP" ] || [ -z "$APE" ]; then echo "Uso: bash empaquetar.sh TP3 apellido"; exit 1; fi

VERSION=2026-11-10
HOST=$(hostname 2>/dev/null || echo vm)
# Con sudo, HOME puede pasar a /root: usar la carpeta de quien llamó a sudo (ahí quedaron las grabaciones)
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
  H=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6); [ -d "$H" ] && HOME="$H"
fi
DIR="$HOME/entrega-$TP"
# Las VMs del laboratorio suelen llamarse igual (localhost): el final de la MAC distingue server y client
MACID=$(ip -o link 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "link/ether") {print $(i + 1); exit}}' | tr -d ':' | tail -c 5)
NOMBRE="entrega-$TP-$APE-$HOST${MACID:+-$MACID}"
TMP=$(mktemp -d 2>/dev/null || { mkdir -p "/tmp/emp-$$"; echo "/tmp/emp-$$"; })
OUT="$TMP/$NOMBRE"
mkdir -p "$OUT"/{sesiones,capturas,config,estado,sistema,extra}
AVISOS="$OUT/AVISOS.txt"; : > "$AVISOS"
aviso() { echo "AVISO: $*" | tee -a "$AVISOS"; }

SUDO=""
if [ "$(id -u)" != "0" ]; then
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then SUDO="sudo -n"
  else aviso "no corrés como root: algunas configuraciones o el ruleset pueden quedar sin leer"; fi
fi
T() { if command -v timeout >/dev/null 2>&1; then timeout 15 "$@"; else "$@"; fi; }

# 1. Grabaciones y respuestas -------------------------------------------------------------------------------------
if [ -d "$DIR/sesiones" ] && ls "$DIR/sesiones/"* >/dev/null 2>&1; then
  cp -p "$DIR/sesiones/"* "$OUT/sesiones/" 2>/dev/null
else
  aviso "no hay grabaciones en $DIR/sesiones (¿usaste grabar.sh?). Se empaqueta igual con el historial y el estado."
fi
[ -f "$DIR/.inicio" ] && cp -p "$DIR/.inicio" "$OUT/sistema/inicio.txt"
if [ -f "$DIR/respuestas.md" ]; then
  cp "$DIR/respuestas.md" "$OUT/respuestas.md"
  grep -q 'COMPLETAR' "$OUT/respuestas.md" && aviso "respuestas.md todavía tiene campos COMPLETAR"
else
  aviso "falta $DIR/respuestas.md (alcanza con que esté en una de las VMs)"
fi
for f in "$DIR"/*.png "$DIR"/*.jpg "$DIR"/*.jpeg "$DIR"/*.pdf "$DIR"/*.txt "$DIR"/*.md; do  # diagrama, notas
  [ -f "$f" ] && [ "$(basename "$f")" != respuestas.md ] && cp -p "$f" "$OUT/extra/" 2>/dev/null
done

# 2. Capturas .pcap: las de la carpeta y las creadas desde que empezaste a grabar ----------------------------------
REF="$DIR/.inicio"; [ -f "$REF" ] || REF=""
for base in "$DIR" "$HOME" /root /tmp "$PWD"; do
  [ -d "$base" ] || continue
  if [ -n "$REF" ]; then
    $SUDO find "$base" -xdev -maxdepth 4 -type f \( -name '*.pcap' -o -name '*.pcapng' -o -name '*.cap' \) -newer "$REF" 2>/dev/null
  fi
  find "$DIR" -maxdepth 2 -type f \( -name '*.pcap' -o -name '*.pcapng' \) 2>/dev/null
done | grep -v 'capturas-referencia' | sort -u | while read -r p; do
  dest="$OUT/capturas/$(printf '%s' "${p#/}" | tr '/' '_')"
  $SUDO cp -p "$p" "$dest" 2>/dev/null && $SUDO chmod a+r "$dest" 2>/dev/null
done
ls "$OUT/capturas/"* >/dev/null 2>&1 || aviso "no se encontró ninguna captura .pcap"

# Logs que guardaste durante el TP (por ejemplo hostapd -f, wpa_supplicant -f, freeradius -X > archivo.log)
if [ -n "$REF" ]; then
  mkdir -p "$OUT/extra/logs"
  for base in "$DIR" "$HOME" /root /tmp; do
    [ -d "$base" ] && $SUDO find "$base" -xdev -maxdepth 3 -type f \( -name '*.log' -o -name '*.txt' \) -size -5M -newer "$REF" 2>/dev/null
  done | grep -vE '/sesiones/|/\.|redes-inalambricas-lab|/entregas-listas/' | grep -vF "$TMP" | sort -u | while read -r p; do
    $SUDO cp -p "$p" "$OUT/extra/logs/$(printf '%s' "${p#/}" | tr '/' '_')" 2>/dev/null
  done
  $SUDO chmod -R a+r "$OUT/extra" 2>/dev/null
fi

# 3. Configuraciones (sólo las que existan; se omiten claves privadas) -------------------------------------------
copiar() { for f in "$@"; do
  [ -e "$f" ] || continue
  case "$f" in *.key|*.pem|*.p12|*/private/*) continue ;; esac
  $SUDO cp -rpL --parents "$f" "$OUT/config/" 2>/dev/null; done; }
copiar /etc/netplan/*.yaml /etc/network/interfaces /etc/network/interfaces.d/* /etc/systemd/network/* \
       /etc/dnsmasq.conf /etc/dnsmasq.d/* /etc/hosts /etc/sysctl.conf /etc/sysctl.d/* /etc/nftables.conf \
       /etc/hostapd/*.conf /etc/hostapd/*.vlan /etc/hostapd/*.eap_user /etc/wpa_supplicant/*.conf \
       /etc/freeradius/3.0/clients.conf \
       /etc/freeradius/3.0/mods-config/files/authorize /etc/freeradius/3.0/users \
       /etc/freeradius/3.0/sites-enabled/* /etc/freeradius/3.0/mods-enabled/eap
# archivos de trabajo del alumno (hostapd*.conf, wpa*.conf, portal.py, *.nft, *.rsc...) creados durante el TP
for base in "$DIR" "$HOME" /root; do
  [ -d "$base" ] || continue
  $SUDO find "$base" -xdev -maxdepth 3 -type f \( -name '*.conf' -o -name '*.nft' -o -name '*.py' -o -name '*.sh' \
       -o -name '*.vlan' -o -name '*.rsc' -o -name '*.yaml' -o -name 'authorize' \) -size -512k \
       ${REF:+-newer "$REF"} 2>/dev/null
done | grep -vE '/\.|redes-inalambricas-lab|/sesiones/' | sort -u | while read -r f; do copiar "$f"; done
$SUDO chmod -R a+rX "$OUT/config" 2>/dev/null

# 4. Estado final de la red (cada comando con límite de tiempo; los que fallan se anotan) -------------------------
N=0
estado() { N=$((N + 1)); local nom="$1"; shift
  local f="$OUT/estado/$(printf %02d $N)-$nom.txt"
  { echo "\$ $*"; T $SUDO bash -c "$*" 2>&1; echo "[código de salida: $?]"; } > "$f"; }
estado ip-addr        "ip addr"
estado ip-route       "ip route; echo; ip -6 route"
estado ip-rule        "ip rule"
estado ip-neigh       "ip neigh"
estado ip-link        "ip -d link"
estado sysctl         "sysctl net.ipv4.ip_forward net.ipv4.conf.all.rp_filter"
estado resolv         "cat /etc/resolv.conf; resolvectl status 2>/dev/null"
estado bridge         "bridge link; echo; bridge vlan show"
estado nft            "nft list ruleset"
estado iptables       "iptables-save 2>/dev/null; iptables -t nat -S 2>/dev/null"
estado conntrack      "conntrack -L 2>/dev/null | head -100"
estado iw             "iw dev; echo; iw list 2>/dev/null | grep -E 'Wiphy|interface' "
estado servicios      "systemctl is-active dnsmasq hostapd freeradius nftables 2>/dev/null; ps -eo pid,etime,args | grep -E 'hostapd|wpa_supplicant|dnsmasq|freeradius|radiusd|portal|python' | grep -v grep"
estado puertos        "ss -tulpn"
estado leases         "cat /var/lib/misc/dnsmasq.leases /var/lib/dhcp/*.leases /run/systemd/netif/leases/* 2>/dev/null"
estado logs-servicios "journalctl -u dnsmasq -u hostapd -u freeradius -n 300 --no-pager 2>/dev/null"
estado kernel-log     "dmesg 2>/dev/null | tail -300"
estado netns          "ip netns list"
for ns in $($SUDO ip netns list 2>/dev/null | awk '{print $1}'); do
  estado "netns-$ns" "echo '## addr'; ip netns exec '$ns' ip addr; echo '## route'; ip netns exec '$ns' ip route; \
    echo '## neigh'; ip netns exec '$ns' ip neigh; echo '## iw'; ip netns exec '$ns' iw dev 2>/dev/null; \
    echo '## nft'; ip netns exec '$ns' nft list ruleset 2>/dev/null; echo '## resolv'; cat /etc/netns/'$ns'/resolv.conf 2>/dev/null"
done

# 5. Identificación del entorno -----------------------------------------------------------------------------------
{
  echo "tp=$TP"; echo "apellido=$APE"; echo "vm=$HOST"; echo "usuario=$(id -un)"; echo "empaquetado=$(date '+%F %T %z')"
  echo "version_empaquetar=$VERSION"
  echo "machine_id=$(sha256sum /etc/machine-id 2>/dev/null | cut -c1-16)"
  echo "macs=$(ip -o link 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "link/ether") print $2 $(i + 1)}' | tr '\n' ' ')"
  echo "uptime=$(uptime 2>/dev/null)"
} > "$OUT/sistema/identidad.txt"
cat /etc/os-release > "$OUT/sistema/os-release.txt" 2>/dev/null
uname -a > "$OUT/sistema/uname.txt" 2>/dev/null
{ dpkg-query -W -f '${Package} ${Version}\n' dnsmasq hostapd wpasupplicant freeradius nftables tcpdump tshark 2>/dev/null \
  || rpm -q dnsmasq hostapd wpa_supplicant freeradius nftables tcpdump wireshark-cli 2>/dev/null; } > "$OUT/sistema/paquetes.txt"
for h in "$HOME/.bash_history" /root/.bash_history; do
  [ -f "$h" ] && $SUDO cp "$h" "$OUT/sistema/historial-$(echo "$h" | tr '/' '_').txt" 2>/dev/null
done
$SUDO chmod -R a+r "$OUT/sistema" 2>/dev/null

# 6. Manifiesto y archivo final -----------------------------------------------------------------------------------
( cd "$OUT" && find . -type f ! -name MANIFIESTO.sha256 -exec sha256sum {} + 2>/dev/null | sort -k2 > MANIFIESTO.sha256 )
FINAL="$HOME/$NOMBRE.tar.gz"
if tar -czf "$FINAL" -C "$TMP" "$(basename "$OUT")" 2>/dev/null; then :; else echo "ERROR: no se pudo crear $FINAL"; exit 1; fi
RESUMEN=$(sed 's/^AVISO: /  - /' "$AVISOS" 2>/dev/null)
rm -rf "$TMP"
mkdir -p "$HOME/entregas-listas" && cp -p "$FINAL" "$HOME/entregas-listas/"      # carpeta que comparte servir.sh
[ -n "${SUDO_USER:-}" ] && chown -R "$SUDO_USER:" "$FINAL" "$HOME/entregas-listas" 2>/dev/null
TAM=$(du -k "$FINAL" | cut -f1)

echo
echo "Listo: $FINAL  (${TAM} KB)"
[ -n "$RESUMEN" ] && { echo "Revisá estos avisos antes de entregar:"; echo "$RESUMEN"; }
if [ "$TAM" -gt 9500 ]; then
  echo "AVISO: pesa más de 9,5 MB y Discord no lo acepta. Borrá capturas que no sean del TP y volvé a empaquetar."
fi
echo "Para bajarlo a tu computadora:  bash $(cd "$(dirname "$0")" && pwd)/servir.sh   (y subilo a tu canal privado entrega-tu-nombre)"
