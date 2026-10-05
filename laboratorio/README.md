# Laboratorio · Enunciados y entorno

| Carpeta | Contenido |
|---|---|
| `enunciados/` | Enunciados de los siete TP, todos con objetivos, topología, consignas con PRUEBAS numeradas, entregables y criterios de evaluación |
| `entorno/` | Creación de VMs y redes (libvirt), guía para VirtualBox y scripts de verificación |

| TP | Tema | Enunciado |
|---|---|---|
| TP1 | DHCP y DNS | `enunciados/TP1-DHCP-DNS.md` |
| TP2 | Gateway, routing y NAT | `enunciados/TP2-ROUTING-NAT.md` |
| TP3 | VLANs 802.1Q, trunk y firewall entre VLANs | `enunciados/TP3-VLAN-FIREWALL.md` |
| TP4 | Portal cautivo para invitados | `enunciados/TP4-CAPTIVE-PORTAL.md` |
| TP5 | 802.1X, EAP (PEAP) y RADIUS | `enunciados/TP5-RADIUS-8021X.md` |
| TP6 | AP Wi-Fi virtual (WPA2-PSK y WPA3-SAE) | `enunciados/TP6-WIFI-VIRTUAL.md` |
| TP7 | Integrador: VLAN dinámica por RADIUS, dos SSIDs, portal y firewall | `enunciados/TP7-INTEGRADOR.md` |
| Complementaria | TP1 a TP4 sobre MikroTik RouterOS (DHCP, DNS, NAT, VLANs, Hotspot) · optativa | `enunciados/COMPLEMENTARIA-MIKROTIK.md` |

La guía paso a paso para el estudiante está en `../guia-estudiante/GUIA-ESTUDIANTE-TPs.md` (la de la actividad complementaria, en `../guia-estudiante/GUIA-COMPLEMENTARIA-MIKROTIK.md`), y la teoría previa a TP1 y TP2, en `../teoria/`.

## Armar el entorno

Las instrucciones de esta sección son para **KVM/libvirt** (el entorno validado). Para **VirtualBox**, ver [`entorno/VIRTUALBOX.md`](entorno/VIRTUALBOX.md).

```bash
cd entorno

# 1. Imagen base: Debian 12 "nocloud" (kernel estándar, necesario para mac80211_hwsim en TP5–TP7)
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2

# 2. Clave SSH propia del laboratorio (create-vm.sh espera lab_key.pub)
ssh-keygen -t ed25519 -N '' -f lab_key

# 3. Redes virtuales aisladas
virsh net-define lab1_net.xml && virsh net-start lab1 && virsh net-autostart lab1   # 10.10.10.0/24
virsh net-define lab2_net.xml && virsh net-start lab2 && virsh net-autostart lab2   # 10.20.20.0/24

# 4. VMs: enp1s0 = red default (Internet), enp2s0 = red del laboratorio
./create-vm.sh lab-server default lab1
./create-vm.sh lab-client lab1
```

Notas:
- La imagen *nocloud* **no incluye cloud-init**: el `seed.iso` que genera `create-vm.sh` no se aplica. El primer acceso es por `virsh console` como `root`.
- La red se configura con **netplan → systemd-networkd** (`/etc/netplan/90-default.yaml`) y el DNS con **systemd-resolved**. No existen `/etc/network/interfaces` ni `dhclient`.
- TP3 a TP7 se realizan **dentro de `lab-server`**, con namespaces como equipos y radios `mac80211_hwsim` como Wi-Fi. `lab-client` no puede asociarse a esas radios.
- En el TP2, el cliente debe salir **sólo** por el router (una única ruta por defecto).
- La imagen *genericcloud* sí trae cloud-init, pero su kernel no incluye `mac80211_hwsim`.

## Actividad complementaria MikroTik

Agrega una tercera VM, `lab-mikrotik`, con RouterOS **CHR** (*Cloud Hosted Router*). Validado con la versión **7.24.5**: si hay una más nueva, la última *stable* figura en <https://mikrotik.com/download>.

```bash
cd entorno

# 1. Imagen del CHR (disco raw de 128 MB)
wget https://download.mikrotik.com/routeros/7.24.5/chr-7.24.5.img.zip
unzip chr-7.24.5.img.zip
mkdir -p vm-data/lab-mikrotik && mv chr-7.24.5.img vm-data/lab-mikrotik/disk.img

# 2. VM: ether1 = red default (WAN) · ether2 = lab1 (LAN y trunk de VLANs)
virt-install --name lab-mikrotik --memory 256 --vcpus 1 \
  --disk "$PWD/vm-data/lab-mikrotik/disk.img,format=raw,bus=sata" \
  --os-variant generic --import --noautoconsole \
  --network network=default --network network=lab1

# 3. Primer acceso por la consola gráfica (el CHR no usa la consola serie)
virt-viewer lab-mikrotik
```

Notas:
- Usuario `admin` sin contraseña; RouterOS obliga a definir una en el primer acceso.
- `lab-server` y `lab-client` deben estar en `lab1`, y el dnsmasq de `lab-server`, detenido. Si quedaron en `lab2` después del TP2: `virt-xml <vm> --edit <n.º de interfaz> --network network=lab1 --update`.
- El host está en `lab1` como `10.10.10.254`. Una vez hecha la Parte 1, se administra con `ssh admin@10.10.10.1` o con el navegador en `http://10.10.10.1` (WebFig).
- Sin licencia, el CHR limita la subida a 1 Mbps por interfaz. Alcanza para el laboratorio.

## Scripts de `entorno/scripts/`

| Script | Dónde se ejecuta | Qué hace |
|---|---|---|
| `verificar-tp1.sh [interfaz]` | `lab-client` | Verifica IP, gateway, DNS (vía `resolvectl`), resolución de `server.lab.local` y ping al servidor |
| `verificar-tp2.sh` | router | Verifica interfaces, forwarding, regla de masquerade, salida a Internet y alcance del cliente |
| `reset-lab.sh` | host | Destruye las VMs del laboratorio (incluida `lab-mikrotik`) |

Las contraseñas y secretos de esta carpeta son **sólo de laboratorio**.
