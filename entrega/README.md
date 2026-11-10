# Cómo entregar los laboratorios (TP1 a TP7)

Cada TP se entrega como **un archivo `.tar.gz` por VM**, que se arma y se sube solo con dos scripts de esta carpeta.
No hace falta informe PDF ni capturas de pantalla: la evidencia es la grabación de tu terminal, tus capturas `.pcap` y
tus configuraciones.

## 0. Traer los scripts a la VM (una vez)

En cada VM que uses, con Internet:

```bash
git clone https://github.com/mendezgarabetti/redes-inalambricas-lab.git   # o, si ya lo tenés:  cd redes-inalambricas-lab && git pull
cd redes-inalambricas-lab
```

> **TP1 y TP2:** hacelo también en `lab-client` **mientras todavía tiene salida a Internet** (cuando instalás los paquetes),
> antes de pasarlo a la red `lab1`/`lab2`.

## 1. Grabá mientras trabajás

```bash
bash entrega/grabar.sh TP3
```

Se abre una terminal con el aviso rojo **`[TP3 grabando]`**. Hacé el TP normalmente: configuraciones, pruebas, `sudo`,
`ip netns exec`, capturas. Todo queda grabado, **también los errores** (está bien: muestran cómo lo resolviste).
Para terminar: `exit`. Si seguís otro día, volvé a correr `grabar.sh TP3` y se agrega otra sesión.

- Guardá las capturas con `tcpdump -w ~/entrega-TP3/nombre.pcap` (si quedan en otra carpeta, el empaquetador las busca igual).
- **TP1 y TP2:** grabá en las dos VMs (`lab-server`/`lab-router` y `lab-client`).
- **Si ya hiciste el TP sin grabar:** no hace falta rehacerlo. Abrí `grabar.sh` y **repetí sólo las PRUEBAS** del enunciado.

## 2. Respondé las preguntas

```bash
nano ~/entrega-TP3/respuestas.md
```

La plantilla ya tiene tu nombre por completar y las preguntas de ese TP. Respondé con lo que observaste **en tu
laboratorio**, citando la salida o la captura que lo muestra. Si trabajaron en grupo, poné **todos** los nombres.
Si el TP pide un diagrama, dibujalo en el `.md` o dejá una imagen `diagrama.png` en `~/entrega-TP3/`.

## 3. Empaquetá y entregá

```bash
sudo bash entrega/empaquetar.sh TP3 tu-apellido
```

Junta todo en `~/entrega-TP3-tu-apellido-<vm>.tar.gz` y **lo sube automáticamente a la cátedra**. Si ves
**`ENTREGADO`**, listo: guardá ese mensaje como comprobante. Si un comando no existe o falla, el script lo anota y sigue.

Si la VM no tiene Internet o la subida falla, el archivo igual queda armado. Opciones:
- **TP1, `lab-client`:** cambiá su red a NAT (VirtualBox: *Configuración → Red → Adaptador 1 → NAT*; libvirt:
  `virsh detach-interface lab-client network --live` y `virsh attach-interface lab-client network default --live`) y
  volvé a correr `empaquetar.sh`. Las grabaciones ya están guardadas, no se pierde nada.
- **Cualquier otro caso:** copiá el `.tar.gz` a tu computadora y subilo a tu canal privado `entrega-tu-nombre` en Discord.

El script **no modifica nada** de tu sistema. Contiene tus comandos, salidas, configuraciones (sin claves privadas),
capturas, la MAC de tus interfaces y tus respuestas.
