#!/usr/bin/env bash
# Comparte tus entregas armadas para bajarlas con el navegador de tu computadora (sin SSH ni contraseñas).
#
#   Uso:  bash servir.sh            (Ctrl+C para terminar)
#
# Sólo comparte la carpeta ~/entregas-listas/, donde empaquetar.sh deja una copia de cada .tar.gz.

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
  H=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6); [ -d "$H" ] && HOME="$H"
fi
DIR="$HOME/entregas-listas"
PUERTO=8000
if ! ls "$DIR"/*.tar.gz >/dev/null 2>&1; then
  echo "No hay entregas en $DIR. Primero corré: sudo bash entrega/empaquetar.sh TPn tu-apellido"; exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Esta VM no tiene python3. Instalalo (apt-get install -y python3) o copiá el archivo con scp."; exit 1
fi

echo "Entregas disponibles:"; ls -1 "$DIR"/*.tar.gz | sed 's|.*/|  - |'
echo
echo "Abrí en el navegador de tu computadora una de estas direcciones y hacé clic en el archivo:"
echo "  - VirtualBox (con el reenvío de puertos 8000 → 8000 del adaptador NAT):  http://127.0.0.1:$PUERTO"
for ip in $(ip -4 -o addr show 2>/dev/null | awk '$2 != "lo" {sub(/\/.*/, "", $4); print $4}'); do
  echo "  - KVM/libvirt o desde otra VM:  http://$ip:$PUERTO"
done
echo
echo "Cuando lo hayas bajado, apretá Ctrl+C para dejar de compartir."
cd "$DIR" && python3 -m http.server "$PUERTO" --bind 0.0.0.0
