# Cómo entregar los laboratorios (TP1 a TP7)

Cada TP se entrega como **un archivo `.tar.gz` por VM**, que se arma con dos scripts de esta carpeta, y se sube a tu
canal privado `entrega-tu-nombre` en Discord. No hace falta informe PDF ni capturas de pantalla: la evidencia es la
grabación de tu terminal, tus capturas `.pcap` y tus configuraciones.

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

La plantilla tiene las preguntas de ese TP. Completá tu nombre y respondé con lo que observaste **en tu laboratorio**,
citando la salida o la captura que lo muestra. Si trabajaron en grupo, poné **todos** los nombres. Si el TP pide un
diagrama, dibujalo en el `.md` o dejá una imagen `diagrama.png` en `~/entrega-TP3/`.

## 3. Empaquetá

```bash
sudo bash entrega/empaquetar.sh TP3 tu-apellido
```

Arma `~/entrega-TP3-tu-apellido-<vm>.tar.gz`. Si un comando no existe o falla, lo anota y sigue. Al final te avisa si
falta algo (respuestas, capturas) o si el archivo pesa más de lo que acepta Discord. No modifica nada de tu sistema.

## 4. Sacá el archivo de la VM y subilo a tu canal privado

- **KVM / libvirt:** desde la terminal de tu computadora, con la clave del laboratorio:
  `scp -i lab_key root@IP-DE-LA-VM:entrega-TP3-*.tar.gz .` (la IP de `lab-server` la ves con `virsh domifaddr lab-server`).
- **VirtualBox:** en el adaptador NAT de la VM agregá un reenvío de puertos (*Configuración → Red → Avanzadas → Reenvío de
  puertos*: TCP, puerto anfitrión 2222, puerto invitado 22), instalá `openssh-server` en la VM y copiá con
  `scp -P 2222 usuario@127.0.0.1:entrega-TP3-*.tar.gz .`
- **VM con escritorio:** subilo directamente desde el navegador de la VM.
- **`lab-client` sin salida (TP1/TP2):** pasalo primero a la otra VM por la red del laboratorio (`scp`) y sacalo desde ahí.

Después subí el `.tar.gz` a tu canal privado **`entrega-tu-nombre`** en Discord. Si no tenés canal, subilo en `#entregas`.
Si te trabás en este paso, preguntá en `#dudas`.
