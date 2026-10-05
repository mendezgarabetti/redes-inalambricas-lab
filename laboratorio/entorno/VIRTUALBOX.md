# Armar el laboratorio en VirtualBox

Alternativa a libvirt/KVM (`create-vm.sh`, `lab*_net.xml`, `reset-lab.sh`) para quienes usan **VirtualBox** en Linux, Windows o macOS con procesador x86-64.

> **Estado:** el laboratorio se validó en KVM/libvirt. En VirtualBox sólo se verificó la conversión de la imagen a VDI y que VirtualBox la reconoce. El resto de los pasos es la traducción directa del entorno libvirt y **no se probó** en VirtualBox. Si encontrás diferencias, avisá por el canal `#dudas`.

## Equivalencias con el entorno libvirt

| libvirt (guía) | VirtualBox |
|---|---|
| Red `default` (NAT con salida a Internet) | Adaptador en modo **NAT** |
| Redes aisladas `lab1` / `lab2` | Adaptador en modo **Red interna**, con nombre `lab1` / `lab2` |
| `enp1s0` (1.ª interfaz) | `enp0s3` (Adaptador 1) |
| `enp2s0` (2.ª interfaz) | `enp0s8` (Adaptador 2) |
| `create-vm.sh` | pasos 2 y 3 de esta guía |
| `reset-lab.sh` | `VBoxManage unregistervm <vm> --delete` |

Los nombres `enp0s3`/`enp0s8` corresponden a la placa por defecto de VirtualBox (Intel PRO/1000). **Verificalos siempre con `ip link`** y reemplazá `enp1s0`/`enp2s0` por los tuyos en netplan, dnsmasq y nftables.

## 1. Descargar y convertir la imagen

Se usa la misma imagen que en el laboratorio (Debian 12 *nocloud*, kernel estándar con `mac80211_hwsim`):

```bash
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2
```

VirtualBox reconoce `.qcow2`, pero su soporte es limitado. Conviene convertirla a **VDI**, una copia por VM (cada disco debe tener su propio identificador):

```bash
qemu-img convert -O vdi debian-12-nocloud-amd64.qcow2 lab-server.vdi
qemu-img convert -O vdi debian-12-nocloud-amd64.qcow2 lab-client.vdi
```

`qemu-img` viene en el paquete `qemu-utils` (Debian/Ubuntu). En Windows, en el instalador de QEMU para Windows; en macOS, con `brew install qemu`.

La imagen trae un disco de 3 GB, insuficiente para instalar los paquetes. Agrandalo a 10 GB:

```bash
VBoxManage modifymedium disk lab-server.vdi --resize 10240
VBoxManage modifymedium disk lab-client.vdi --resize 10240
```

## 2. Crear las VMs

Con la interfaz gráfica: **Nueva** → tipo *Linux*, versión *Debian (64-bit)* → **Usar un disco duro virtual existente** → el `.vdi`. Después, en **Configuración → Red**, configurá los adaptadores según la tabla del paso 3.

O por línea de comandos:

```bash
# lab-server: 2 GB, 2 CPU. Adaptador 1 = NAT, Adaptador 2 = red interna lab1
VBoxManage createvm --name lab-server --ostype Debian_64 --register
VBoxManage modifyvm lab-server --memory 2048 --cpus 2 \
    --nic1 nat --nic2 intnet --intnet2 lab1
VBoxManage storagectl lab-server --name SATA --add sata --controller IntelAhci
VBoxManage storageattach lab-server --storagectl SATA --port 0 --device 0 \
    --type hdd --medium lab-server.vdi

# lab-client: 1 GB, 1 CPU. Un solo adaptador en la red interna lab1
VBoxManage createvm --name lab-client --ostype Debian_64 --register
VBoxManage modifyvm lab-client --memory 1024 --cpus 1 \
    --nic1 intnet --intnet1 lab1
VBoxManage storagectl lab-client --name SATA --add sata --controller IntelAhci
VBoxManage storageattach lab-client --storagectl SATA --port 0 --device 0 \
    --type hdd --medium lab-client.vdi
```

## 3. Redes para cada TP

| TP | lab-server | lab-client |
|---|---|---|
| TP1 | Adaptador 1: NAT · Adaptador 2: red interna `lab1` | Adaptador 1: red interna `lab1` |
| TP2 | Adaptador 1: NAT (WAN) · Adaptador 2: red interna `lab2` (LAN) | Adaptador 1: red interna `lab2` |
| TP3–TP7 | Adaptador 1: NAT (se usan namespaces dentro de la VM) | no se usa |

Para pasar del TP1 al TP2, cambiá la red interna de `lab1` a `lab2` en ambas VMs, con la VM apagada:

```bash
VBoxManage modifyvm lab-server --intnet2 lab2
VBoxManage modifyvm lab-client --intnet1 lab2
```

> **Importante en el TP2:** el cliente debe tener **un solo** adaptador, en `lab2`. Si además tiene uno en NAT, sale a Internet por su cuenta y las pruebas del TP2 no demuestran nada.

Las redes internas de VirtualBox **no tienen DHCP** mientras no lo configures, igual que `lab1`/`lab2` en libvirt: el DHCP lo da dnsmasq en el TP1.

## 4. Primer arranque

1. Iniciá la VM y entrá en la consola como `root` (sin contraseña). Poné una contraseña con `passwd`.
2. Verificá que el disco se haya agrandado: `df -h /`. Si `/` sigue mostrando unos 3 GB, extendé la partición (en esta imagen el sistema está en la partición 1; confirmalo con `lsblk`):
   ```bash
   apt-get update && apt-get install -y cloud-guest-utils
   growpart /dev/sda 1
   resize2fs /dev/sda1
   ```
3. Instalá los paquetes del laboratorio (sección 0.2 de `guia-estudiante/GUIA-ESTUDIANTE-TPs.md`).

## 5. Red dentro de la VM

Igual que en la guía (netplan → systemd-networkd), cambiando los nombres de interfaz. Por ejemplo, TP1 en `lab-server`:

```yaml
# /etc/netplan/90-default.yaml
network:
  version: 2
  ethernets:
    enp0s3: {dhcp4: true}                                  # NAT
    enp0s8: {dhcp4: false, addresses: [10.10.10.10/24]}    # red interna lab1
```

y en dnsmasq, `interface=enp0s8`. En el TP2, la regla de NAT usa la interfaz WAN: `oifname "enp0s3" masquerade`.

## 6. Scripts de verificación

`scripts/verificar-tp1.sh` y `scripts/verificar-tp2.sh` funcionan igual, porque se ejecutan dentro de las VMs. Al de TP1 pasale la interfaz del laboratorio:

```bash
./verificar-tp1.sh enp0s3      # en lab-client (su único adaptador)
```

## 7. TP3 a TP7

No requieren nada especial de VirtualBox: VLANs, bridges, namespaces y la radio Wi-Fi virtual (`mac80211_hwsim`) son funciones del kernel de la VM y funcionan igual en cualquier hipervisor. Sólo reemplazá `enp1s0` por `enp0s3` en los comandos que usan la salida a Internet (NAT de nftables y reglas del firewall).

## 8. Actividad complementaria MikroTik

> **No se probó en VirtualBox.** La actividad se validó en KVM/libvirt (ver `laboratorio/README.md`).

MikroTik publica el CHR también como disco **VDI**:

```bash
wget https://download.mikrotik.com/routeros/7.24.5/chr-7.24.5.vdi.zip
unzip chr-7.24.5.vdi.zip

VBoxManage createvm --name lab-mikrotik --ostype Linux26_64 --register
VBoxManage modifyvm lab-mikrotik --memory 256 --cpus 1 \
    --nic1 nat --nic2 intnet --intnet2 lab1
VBoxManage storagectl lab-mikrotik --name SATA --add sata --controller IntelAhci
VBoxManage storageattach lab-mikrotik --storagectl SATA --port 0 --device 0 \
    --type hdd --medium chr-7.24.5.vdi
```

- El Adaptador 1 es `ether1` (WAN) y el Adaptador 2 es `ether2` (LAN y trunk de VLANs).
- `lab-server` (Adaptador 2) y `lab-client` deben estar en la red interna `lab1`.
- El host **no** está en la red interna: administrá el router desde la ventana de la VM o con `ssh admin@10.10.10.1` desde `lab-client`.
