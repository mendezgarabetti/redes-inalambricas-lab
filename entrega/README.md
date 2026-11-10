# Cómo entregar los laboratorios (TP1 a TP7)

Cada TP se entrega como **un archivo `.tar.gz` por VM**, que se arma con los scripts de esta carpeta y se sube a tu
canal privado `entrega-tu-nombre` en Discord. No hace falta informe PDF ni capturas de pantalla: la evidencia es la
grabación de tu terminal, tus capturas `.pcap`, tus logs y tus configuraciones.

> En los ejemplos se usa **TP3**: reemplazalo por el TP que estés haciendo (`TP1` … `TP7`, o `MK` para MikroTik).

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
`ip netns exec`, capturas. Se guarda **el texto** de esa terminal (comandos, salidas y también los errores, con la
hora); no es un video ni graba otras ventanas. Para terminar: `exit`. Si seguís otro día, volvé a correr
`grabar.sh TP3` y se agrega otra sesión.

- **¿Usás varias terminales a la vez** (por ejemplo `tcpdump` en una y `hostapd` en otra)? Corré `grabar.sh TP3` **en
  cada una**: cada terminal queda como una sesión aparte.
- Guardá las capturas con `tcpdump -w ~/entrega-TP3/nombre.pcap`, y los logs con `-f archivo.log` (hostapd,
  wpa_supplicant). Si quedan en otra carpeta, el empaquetador los busca igual.
- **TP1 y TP2:** grabá en las dos VMs (`lab-server`/`lab-router` y `lab-client`).
- **Si ya hiciste el TP sin grabar:** no hace falta rehacerlo. Abrí `grabar.sh` y **repetí sólo las PRUEBAS** del enunciado.

## 2. Respondé las preguntas

```bash
nano ~/entrega-TP3/respuestas.md
```

La plantilla tiene las preguntas de ese TP. Completá tu nombre y respondé con lo que observaste **en tu laboratorio**,
citando la salida o la captura que lo muestra. Si trabajaron en grupo, poné **todos** los nombres. Si el TP pide un
diagrama, dibujalo en el `.md` o dejá una imagen `diagrama.png` en `~/entrega-TP3/`.

## 3. Empaquetá

```bash
sudo bash entrega/empaquetar.sh TP3 tu-apellido
```

Arma `entrega-TP3-tu-apellido-<vm>.tar.gz` (en tu carpeta y en `~/entregas-listas/`). Si un comando no existe o falla,
lo anota y sigue. Al final te avisa si falta algo (respuestas, capturas) o si pesa más de lo que acepta Discord. No
modifica nada de tu sistema.

## 4. Bajalo a tu computadora y subilo a tu canal privado

En la VM:

```bash
bash entrega/servir.sh
```

Te muestra qué dirección abrir en el **navegador de tu computadora**; hacé clic en el archivo para bajarlo y después
`Ctrl+C` en la VM.

- **KVM / libvirt:** abrí la dirección `http://IP-DE-LA-VM:8000` que te muestra el script.
- **VirtualBox:** una sola vez, en *Configuración → Red → Adaptador 1 (NAT) → Avanzadas → Reenvío de puertos*, agregá
  una regla TCP con puerto anfitrión **8000** y puerto invitado **8000**. Después abrí `http://127.0.0.1:8000`.
- **`lab-client` sin salida (TP1/TP2):** corré `servir.sh` en el cliente y, desde la otra VM, bajalo con
  `cd ~/entregas-listas && curl -O http://IP-DEL-CLIENTE:8000/NOMBRE-DEL-ARCHIVO.tar.gz`. Después corré `servir.sh`
  en esa VM y bajá los dos archivos a tu computadora.
- También sirve `scp`, si ya lo usás.

Subí el `.tar.gz` (uno por VM) a tu canal privado **`entrega-tu-nombre`** en Discord. Si no tenés canal, subilo en
`#entregas`. Si te trabás en algún paso, preguntá en `#dudas`.
