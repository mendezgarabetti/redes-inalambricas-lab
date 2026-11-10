#!/usr/bin/env bash
# Graba todo lo que hacés en la terminal mientras resolvés un TP (comandos, salidas y errores, con la hora).
#
#   Uso:   bash grabar.sh TP3
#   Salir: escribí  exit  (o Ctrl+D). Podés grabar varias veces: cada vez se agrega una sesión nueva.
#
# No cambia nada de tu sistema: sólo crea la carpeta ~/entrega-TPn/ con las grabaciones y la plantilla de respuestas.
# Los errores también se graban, y está bien: muestran cómo trabajaste.

TP=$(printf '%s' "${1:-}" | tr '[:lower:]' '[:upper:]')
case "$TP" in
  TP1|TP2|TP3|TP4|TP5|TP6|TP7|MK) ;;
  *) echo "Uso: bash grabar.sh TP1   (TP1 a TP7, o MK para la actividad con MikroTik)"; exit 1 ;;
esac

AQUI=$(cd "$(dirname "$0")" && pwd)
DIR="$HOME/entrega-$TP"
mkdir -p "$DIR/sesiones" || { echo "No pude crear $DIR"; exit 1; }
[ -f "$DIR/.inicio" ] || date '+%F %T %z' > "$DIR/.inicio"      # marca de inicio (la usa empaquetar.sh)
if [ ! -f "$DIR/respuestas.md" ] && [ -f "$AQUI/respuestas/$TP.md" ]; then
  cp "$AQUI/respuestas/$TP.md" "$DIR/respuestas.md"
fi

N=1; while ls "$DIR/sesiones/sesion-$(printf %02d $N)-"* >/dev/null 2>&1; do N=$((N + 1)); done
BASE="$DIR/sesiones/sesion-$(printf %02d $N)-$(hostname 2>/dev/null || echo vm)"

RC=$(mktemp 2>/dev/null || echo "/tmp/grabar-rc-$$")
cat > "$RC" <<EOF
[ -f "\$HOME/.bashrc" ] && . "\$HOME/.bashrc"
HISTFILE="$BASE.historial"; HISTTIMEFORMAT='%F %T  '; shopt -s histappend; PROMPT_COMMAND='history -a'
PS1='\[\e[41;97m\][$TP grabando]\[\e[0m\] \u@\h:\w\\$ '
echo "== $TP · sesión $N · \$(date '+%F %T') · \$(hostname) =="
EOF

echo
echo "Grabando la sesión $N del $TP en $DIR/sesiones/"
echo "Trabajá normalmente (también con sudo o dentro de los namespaces). Para terminar: exit"
echo "Si abrís otra terminal para este TP, corré grabar.sh $TP también ahí."
echo "Guardá tus capturas .pcap en $DIR/ (empaquetar.sh también busca las que dejes en otro lado)."
echo

if script --help 2>&1 | grep -q -- '--log-timing'; then
  script -q -f --log-out "$BASE.log" --log-timing "$BASE.tiempos" -c "bash --rcfile '$RC' -i"
elif command -v script >/dev/null 2>&1; then
  script -q -f -c "bash --rcfile '$RC' -i" "$BASE.log"
else
  echo "AVISO: este sistema no tiene el comando 'script' (paquete util-linux o bsdutils)."
  echo "Se guarda sólo el historial de comandos, sin las salidas. Si podés, instalalo y volvé a empezar."
  bash --rcfile "$RC" -i
fi
rm -f "$RC"

echo
echo "Sesión $N guardada. Cuando termines el TP:"
echo "  1. Completá tus respuestas:   nano $DIR/respuestas.md"
echo "  2. Armá la entrega:           bash $AQUI/empaquetar.sh $TP tu-apellido"
