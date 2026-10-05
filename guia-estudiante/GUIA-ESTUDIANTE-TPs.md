# Guía del estudiante · Laboratorio de Redes Inalámbricas (TP1 a TP7)

**Materia:** Redes Inalámbricas · ITU · Universidad Nacional de Cuyo
**Versión:** 28/09/2026

Esta guía te acompaña en el desarrollo de los siete trabajos prácticos. Los **TP1 y TP2** (DHCP, DNS, routing y NAT) se resumen como procedimiento operativo, porque su teoría está en las presentaciones 01 a 05 (`../teoria/` en este repositorio). El énfasis está en los **temas avanzados**:

| TP | Tema avanzado | Idea que tenés que llevarte |
|---|---|---|
| TP3 | VLAN 802.1Q, trunk, router *on a stick*, firewall entre VLANs | Un SSID o un puerto no es una red IP: la VLAN separa en capa 2 y el router/firewall decide qué se cruza. |
| TP4 | Portal cautivo | Interceptar HTTP es fácil; HTTPS no se puede interceptar sin romper TLS. El “login” es una regla de firewall por cliente. |
| TP5 | 802.1X, EAP, RADIUS | El AP no conoce las contraseñas: transporta EAP entre el cliente y RADIUS, y recibe una clave (PMK) para cifrar. |
| TP6 | Radio Wi-Fi virtual | Beacons, autenticación, asociación y 4-way handshake son tramas reales que podés capturar. |
| TP7 | Integración | RADIUS puede decidir **en qué VLAN** entra cada usuario. |

> **Todo lo que aparece como “salida real” en esta guía se obtuvo al validar los procedimientos** en Debian 12.15 (kernel 6.1), hostapd/wpa_supplicant 2.10, FreeRADIUS 3.2.1, nftables 1.0.6 y tshark 4.0.17. Tus direcciones MAC, IDs y tiempos serán distintos, pero la **forma** del resultado debe coincidir. En la carpeta `capturas-referencia/` hay capturas `.pcap` de referencia para comparar con las tuyas, y en `configs/`, los archivos de configuración validados.

---

## Índice

0. [Antes de empezar: entorno, reglas y evidencias](#0-antes-de-empezar)
1. [TP1 · DHCP y DNS](#tp1--dhcp-y-dns-repaso-operativo)
2. [TP2 · Gateway, routing y NAT](#tp2--gateway-routing-y-nat-repaso-operativo)
3. [TP3 · VLANs, trunk y firewall entre VLANs](#tp3--vlans-trunk-y-firewall-entre-vlans)
4. [TP4 · Portal cautivo](#tp4--portal-cautivo)
5. [TP5 · 802.1X, EAP y RADIUS](#tp5--wi-fi-empresarial-8021x-eap-y-radius)
6. [TP6 · Wi-Fi completamente virtual](#tp6--wi-fi-completamente-virtual)
7. [TP7 · Integrador](#tp7--integrador)
8. [Troubleshooting general](#8-troubleshooting-general)
9. [Anexos](#9-anexos)

**Orden recomendado:** TP1 → TP2 → TP3 → TP4 → **TP6 → TP5** → TP7. La parte B del TP5 (802.1X real) usa la radio virtual del TP6, así que conviene hacer primero el TP6.

**Actividad complementaria (optativa):** después del TP4 podés repetir los TP1 a TP4 sobre un router **MikroTik RouterOS**. Ver `GUIA-COMPLEMENTARIA-MIKROTIK.md`.

---

## 0. Antes de empezar

### 0.1 El entorno

Trabajás con máquinas virtuales Debian 12 sobre KVM/libvirt:

| VM | Uso | Interfaces |
|---|---|---|
| `lab-server` | Servidor (TP1), router (TP2), AP + RADIUS + firewall (TP3–TP7) | `enp1s0` → red `default` (salida a Internet vía NAT del host) · `enp2s0` → red del laboratorio (`lab1` o `lab2`) |
| `lab-client` | Cliente cableado (TP1, TP2) | `enp2s0` → red del laboratorio (y, según cómo se creó, también `enp1s0` → `default`: ver TP2) |

Tres características de estas imágenes que **cambian los comandos respecto de muchos tutoriales**:

1. **La red se configura con netplan**, que genera la configuración de systemd-networkd. No existe `/etc/network/interfaces` y `dhclient` no está instalado. El archivo de fábrica es `/etc/netplan/90-default.yaml` y pone **DHCP en todas las interfaces `en*`**.
2. **El DNS del sistema lo maneja systemd-resolved**: `/etc/resolv.conf` apunta a `127.0.0.53` y el DNS real se ve con `resolvectl status`.
3. systemd-resolved ocupa el puerto 53 en `127.0.0.53`. **Si instalás dnsmasq sin más, el servicio queda en `failed`**: hay que usar `bind-interfaces` (se ve en el TP1).

> **La radio Wi-Fi virtual vive dentro de un kernel.** `mac80211_hwsim` crea radios que sólo “se escuchan” entre sí **dentro de la misma VM**. Por eso, en TP5, TP6 y TP7, el AP y los clientes inalámbricos están en `lab-server`: cada cliente es un *network namespace*, que se comporta como otra computadora con su propia pila de red. `lab-client` no puede asociarse a esa radio.

### 0.2 Herramientas que vas a usar en todos los TP

```bash
ip -br addr           # interfaces e IPs (resumen)
ip route              # tabla de rutas;  ip route get <IP> = qué ruta usaría
ip neigh              # caché ARP
networkctl list       # estado según systemd-networkd
resolvectl status     # DNS configurado por interfaz
ss -lunp              # quién escucha en qué puerto UDP
nft list ruleset      # reglas de firewall / NAT cargadas
tcpdump -i <if> -n [-e] [-w archivo.pcap] <filtro>   # captura
tshark -r archivo.pcap -Y "<filtro de visualización>" # análisis por consola
ip netns exec <ns> <comando>                          # ejecutar "en otra computadora"
```

> Los archivos de `configs/` se copian a la ruta que usan los comandos de cada TP; por ejemplo: `sudo cp configs/hostapd-tp6-psk.conf /etc/hostapd/tp6-psk.conf` y `cp configs/wpa-tp6-psk.conf /root/tp6-wpa.conf`. Cada paso indica la ruta de destino.

Para instalar todo lo necesario en `lab-server` (una sola vez):

```bash
sudo apt-get update
sudo apt-get install -y dnsmasq tcpdump tshark bind9-dnsutils curl nftables conntrack \
     hostapd wpasupplicant iw freeradius freeradius-utils isc-dhcp-client
```

### 0.3 Reglas de trabajo

- **Un cambio por vez.** Probá, anotá y seguí. Si cambiás tres cosas y algo se rompe, no vas a saber cuál fue.
- **Registrá la terminal:** `script -a evidencias/tpN-terminal.log` graba todo lo que hacés (salís con `exit`).
- **Guardá capturas en archivo** (`tcpdump -w`) además de mirarlas en pantalla: el `.pcap` es la evidencia.
- **Snapshot antes de cada TP avanzado:** `virsh snapshot-create-as lab-server antes-tp3` (lo hace quien administre el host).
- **Aplicá `netplan apply` desde la consola** (`virsh console lab-server`), no por SSH. Reinicia systemd-networkd y puede dejarte sin conexión por un momento o borrar IPs que agregaste a mano. Configurá netplan **antes** de levantar servicios (hostapd, bridges).
- Las contraseñas de esta guía (`alumno123`, `testing123`, etc.) son **sólo de laboratorio**.

### 0.4 Qué se entrega en cada TP

Un informe PDF por TP con: topología (dibujo con IPs, VLANs e interfaces), configuraciones aplicadas, evidencias (salidas de comandos + capturas `.pcap` o recortes de tshark/Wireshark **señalando qué demuestra cada una**), respuestas a las preguntas de análisis y problemas encontrados con su solución.

---

## TP1 · DHCP y DNS (repaso operativo)

**Teoría:** presentaciones 01 (DHCP) y 02 (DNS). **Topología:** `lab-server` 10.10.10.10/24 y `lab-client` por DHCP, en la red `lab1`.

### Paso 1 · IP estática del servidor con netplan

Editá `/etc/netplan/90-default.yaml` en `lab-server` (reemplazá el contenido, permisos `600`):

```yaml
network:
  version: 2
  ethernets:
    enp1s0:            # WAN: salida para instalar paquetes
      dhcp4: true
    enp2s0:            # LAN del laboratorio
      dhcp4: false
      addresses: [10.10.10.10/24]
```

```bash
sudo chmod 600 /etc/netplan/90-default.yaml
sudo netplan apply            # desde la consola
ip -br addr show enp2s0       # debe mostrar 10.10.10.10/24
```

> ¿Por qué hace falta? El archivo de fábrica pone DHCP en **todas** las interfaces `en*`, y el servidor DHCP no puede pedirse una IP a sí mismo.

### Paso 2 · dnsmasq (DHCP + DNS)

`/etc/dnsmasq.d/tp1.conf`:

```ini
bind-interfaces          # sin esto, choca con systemd-resolved en el puerto 53
interface=enp2s0
domain=lab.local
dhcp-range=10.10.10.100,10.10.10.200,255.255.255.0,1h
dhcp-option=option:router,10.10.10.1
dhcp-option=option:dns-server,10.10.10.10
address=/server.lab.local/10.10.10.10
address=/router.lab.local/10.10.10.1
```

```bash
sudo dnsmasq --test && sudo systemctl restart dnsmasq && systemctl is-active dnsmasq
ss -lunp | grep dnsmasq       # debe escuchar en 10.10.10.10:53 y en :67
```

### Paso 3 · Pruebas en el cliente

| Prueba | Comando | Qué esperás |
|---|---|---|
| IP y máscara | `ip -br addr show enp2s0` | 10.10.10.1xx/24 (dentro del pool); `ip addr` muestra `dynamic` y `valid_lft` |
| Gateway | `ip route` | `default via 10.10.10.1 dev enp2s0 proto dhcp` |
| DNS | `resolvectl status enp2s0` | `DNS Servers: 10.10.10.10` · `DNS Domain: lab.local` |
| Renovar | `sudo networkctl renew enp2s0` | En la captura: **sólo Request + ACK** (renovación) |
| DORA completo | `sudo networkctl reconfigure enp2s0` | En la captura: **Release, Discover, Offer, Request, ACK** |
| Resolver | `dig server.lab.local` | `status: NOERROR`, `A 10.10.10.10`, `SERVER: 10.10.10.10#53` |
| Fallo DNS | en el servidor, `sudo systemctl stop dnsmasq` | `ping 10.10.10.10` funciona; `ping server.lab.local` falla |

**Salida real** (validación) de las dos formas de disparar DHCP con systemd-networkd:

```text
networkctl renew        →  Request, ACK
networkctl reconfigure  →  Release, Discover, Offer, Request, ACK
```

Captura: `sudo tcpdump -i enp2s0 -n -v -w tp1-dhcp.pcap udp port 67 or udp port 68`. En Wireshark: filtro `dhcp`; buscá Transaction ID, Client MAC, opción 53, *Your IP*, opciones 3, 6, 51 y 54.

**Preguntas de análisis:** ¿por qué `renew` no genera un Discover? ¿Existe algún equipo con la IP del gateway informado (10.10.10.1)? Con dnsmasq detenido, ¿por qué el cliente conserva su IP?

---

## TP2 · Gateway, routing y NAT (repaso operativo)

**Teoría:** presentaciones 03 (routing) y 04 (NAT). **Topología:** `lab-router` (WAN `enp1s0` por DHCP, LAN `enp2s0` 10.20.20.1/24 en `lab2`) y `lab-client` 10.20.20.100/24.

### ⚠ Condición de validez: el cliente sólo debe salir por el router

Si `lab-client` tiene también una interfaz en la red `default`, **tiene Internet por su cuenta** y todas las pruebas del TP2 dan “OK” aunque el router esté mal configurado. Antes de empezar, en el cliente:

```bash
ip route        # debe haber UNA sola ruta default, y debe ser via 10.20.20.1
```

Si aparece `default via 192.168.122.1 dev enp1s0`, dejá esa interfaz fuera de netplan y bajala (`sudo ip link set enp1s0 down`), o pedile al docente que la quite de la VM.

### Configuración

Router (`/etc/netplan/90-default.yaml`):

```yaml
network:
  version: 2
  ethernets:
    enp1s0: {dhcp4: true}                      # WAN
    enp2s0: {dhcp4: false, addresses: [10.20.20.1/24]}   # LAN
```

Cliente:

```yaml
network:
  version: 2
  ethernets:
    enp2s0:
      dhcp4: false
      addresses: [10.20.20.100/24]
      routes: [{to: default, via: 10.20.20.1}]
      nameservers: {addresses: [8.8.8.8]}
```

Forwarding persistente en el router:

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-router.conf
sudo sysctl --system && sysctl net.ipv4.ip_forward     # → 1
```

NAT persistente (`/etc/nftables.conf`):

```text
flush ruleset
table ip nat {
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
    oifname "enp1s0" masquerade
  }
}
```

```bash
sudo nft -f /etc/nftables.conf && sudo systemctl enable --now nftables
```

### Pruebas

| Prueba | Dónde | Comando | Resultado esperado |
|---|---|---|---|
| Gateway | cliente | `ping -c3 10.20.20.1` | responde |
| Salida del router | router | `ping -c3 8.8.8.8` | responde |
| Internet | cliente | `ping -c3 1.1.1.1` · `curl -I https://example.com` | responde · `HTTP/2 200` |
| Primer salto | cliente | `traceroute -n 1.1.1.1` | salto 1 = 10.20.20.1 |
| NAT visible | router | `tcpdump -n -i enp2s0 icmp` y `tcpdump -n -i enp1s0 icmp` | LAN: origen 10.20.20.100 · WAN: origen = IP WAN del router |
| Sin forwarding | router | `sudo sysctl -w net.ipv4.ip_forward=0` | el cliente llega al router, no más allá |
| Sin NAT | router | `sudo nft flush chain ip nat postrouting` | en la WAN sale el origen 10.20.20.100 y no vuelve respuesta |

> **Trampa de conntrack:** al borrar la regla de NAT, un `ping` que ya estaba corriendo **puede seguir funcionando**, porque la traducción quedó en la tabla de estado. Cortalo y lanzá uno nuevo (o `sudo conntrack -F`).

> **NAT doble:** la WAN del router (192.168.122.x) también es privada; el host hace un segundo NAT. En la captura WAN no vas a ver una IP pública.

---

## TP3 · VLANs, trunk y firewall entre VLANs

### Por qué importa en Wi-Fi

Un campus tiene un solo cableado y los mismos AP para docentes, estudiantes e invitados. Para separarlos, **cada SSID (o cada usuario, en el TP7) se asocia a una VLAN**, y el AP envía el tráfico al switch por un **trunk** con etiquetas 802.1Q. Separar en capa 2 no alcanza: alguien tiene que **rutear** entre VLANs, y ese router es el lugar donde el **firewall** decide qué se permite.

### Conceptos que tenés que manejar

- **Etiqueta 802.1Q:** 4 bytes insertados en la trama Ethernet. TPID `0x8100` + prioridad (3 bits) + **VID** de 12 bits (1–4094).
- **Puerto de acceso:** pertenece a una sola VLAN y sus tramas viajan **sin** etiqueta. El switch agrega o quita la etiqueta (PVID).
- **Puerto trunk:** transporta varias VLANs, **con** etiqueta.
- **Router *on a stick*:** un router con **una** interfaz física y una subinterfaz por VLAN (`eth0.10`, `eth0.20`), cada una con el gateway de su red.
- **Aislamiento:** dos equipos en VLANs distintas no se ven en capa 2 **aunque tengan IPs de la misma subred**. Para comunicarse necesitan un router, y el router puede filtrar.

### Topología (todo en `lab-server`, con namespaces)

```text
   pc10 (VLAN 10)          pc20 (VLAN 20)
   192.168.10.10           192.168.20.10
        │ p10 (acceso, PVID 10)   │ p20 (acceso, PVID 20)
        └──────────┬──────────────┘
              [ sw ]  bridge Linux con vlan_filtering
                   │ ptrunk (trunk: VLAN 10 y 20 etiquetadas)
              router: eth0.10 = 192.168.10.1
                      eth0.20 = 192.168.20.1
```

### Parte A · El switch y los puertos

```bash
# "computadoras" y router
for n in pc10 pc20 router; do sudo ip netns add $n; sudo ip -n $n link set lo up; done

# switch con filtrado de VLAN
sudo ip link add sw type bridge vlan_filtering 1
sudo ip link set sw up

# cables (veth): un extremo en el switch, el otro en cada equipo
sudo ip link add p10    type veth peer name eth0 netns pc10
sudo ip link add p20    type veth peer name eth0 netns pc20
sudo ip link add ptrunk type veth peer name eth0 netns router
for p in p10 p20 ptrunk; do
  sudo ip link set $p master sw up
  sudo bridge vlan del dev $p vid 1        # sacar la VLAN 1 por defecto
done

# acceso: una VLAN, sin etiqueta hacia el equipo
sudo bridge vlan add dev p10 vid 10 pvid untagged
sudo bridge vlan add dev p20 vid 20 pvid untagged
# trunk: varias VLANs, etiquetadas
sudo bridge vlan add dev ptrunk vid 10
sudo bridge vlan add dev ptrunk vid 20
bridge vlan show
```

**Salida real:**

```text
p10               10 PVID Egress Untagged
p20               20 PVID Egress Untagged
ptrunk            10
                  20
```

### Parte B · Equipos y router *on a stick*

```bash
sudo ip -n pc10 addr add 192.168.10.10/24 dev eth0; sudo ip -n pc10 link set eth0 up
sudo ip -n pc10 route add default via 192.168.10.1
sudo ip -n pc20 addr add 192.168.20.10/24 dev eth0; sudo ip -n pc20 link set eth0 up
sudo ip -n pc20 route add default via 192.168.20.1

R="sudo ip netns exec router"
$R ip link set eth0 up
$R ip link add link eth0 name eth0.10 type vlan id 10
$R ip link add link eth0 name eth0.20 type vlan id 20
$R ip addr add 192.168.10.1/24 dev eth0.10; $R ip link set eth0.10 up
$R ip addr add 192.168.20.1/24 dev eth0.20; $R ip link set eth0.20 up
```

### Parte C · Experimentos (en este orden)

| # | Estado del router | Prueba | Resultado real |
|---|---|---|---|
| 1 | `ip_forward = 0` | pc10 → 192.168.10.1 | OK |
| 2 | `ip_forward = 0` | pc10 → 192.168.20.10 | **sin respuesta** |
| 3 | `ip_forward = 1` | pc10 ↔ pc20 | OK en ambos sentidos |
| 4 | + firewall (abajo) | pc20 → pc10 | OK |
| 5 | + firewall | pc10 → pc20 | **sin respuesta** |

```bash
$R sysctl -w net.ipv4.ip_forward=1
$R nft -f - <<'EOF'
table inet tp3 {
  chain forward {
    type filter hook forward priority filter; policy drop;
    ct state established,related accept
    iifname "eth0.20" oifname "eth0.10" accept comment "docentes -> alumnos"
  }
}
EOF
```

**Capturá el trunk y un puerto de acceso al mismo tiempo** mientras pc20 hace ping a pc10:

```bash
sudo tcpdump -i ptrunk -e -n icmp      # terminal 1
sudo tcpdump -i p10    -e -n icmp      # terminal 2
sudo ip netns exec pc20 ping -c2 192.168.10.10
```

**Salida real** (recortada):

```text
ptrunk: ... ethertype 802.1Q (0x8100), length 102: vlan 20, p 0, ethertype IPv4, 192.168.20.10 > 192.168.10.10 ...
ptrunk: ... ethertype 802.1Q (0x8100), length 102: vlan 10, p 0, ethertype IPv4, 192.168.20.10 > 192.168.10.10 ...
p10:    ... ethertype IPv4 (0x0800), length 98: 192.168.20.10 > 192.168.10.10: ICMP echo request ...
```

El **mismo** ping pasa **dos veces** por el trunk: primero con etiqueta `vlan 20` (de pc20 al router) y después con `vlan 10` (del router a pc10). En el puerto de acceso llega **sin etiqueta** y 4 bytes más corto (98 vs. 102).

### Preguntas de análisis

1. ¿Por qué el ping del experimento 2 falla si el router tiene IP en ambas VLANs?
2. Explicá la diferencia de 4 bytes entre la trama del trunk y la del puerto de acceso.
3. ¿Por qué la regla `ct state established,related accept` permite que pc10 **responda** a pc20, aunque pc10 no pueda **iniciar** una comunicación hacia pc20?
4. Poné a pc20 en la subred 192.168.10.0/24 pero dejalo en la VLAN 20. ¿Se comunica con pc10? ¿Qué demuestra?
5. En un campus real, ¿en qué equipo estaría cada pieza: switch, trunk, router, firewall, AP?

### Errores típicos

| Síntoma | Causa |
|---|---|
| Todo se comunica con todo | Olvidaste `vlan_filtering 1` en el bridge: sin él, ignora las VLANs |
| Nada pasa por el trunk | Falta `bridge vlan add dev ptrunk vid X`, o quedó la VLAN 1 como PVID |
| El router no responde en una VLAN | Subinterfaz sin `up`, o creada sobre la interfaz equivocada |
| Con firewall no vuelven las respuestas | Falta la regla `ct state established,related accept` |

**Variante con dos VMs** (no validada en esta revisión): subinterfaces `enp2s0.10`/`enp2s0.20` en `lab-server` y `enp2s0.10` en `lab-client`, sobre la red `lab2`. El bridge de libvirt reenvía las tramas etiquetadas de forma transparente.

---

## TP4 · Portal cautivo

### Cómo funciona un portal cautivo real

1. El invitado se asocia a un SSID **abierto** y recibe IP por DHCP.
2. El firewall del gateway lo trata como **no autorizado**: sólo le permite DHCP, DNS y el portal.
3. Cuando el sistema operativo o el navegador hacen una petición **HTTP**, el gateway la **redirige** (DNAT) al servidor del portal.
4. El usuario acepta los términos (o se autentica) y el portal **agrega la IP (o la MAC) del cliente a una lista de autorizados**, normalmente con vencimiento.
5. Desde ese momento el firewall deja pasar su tráfico y ya no lo redirige.

**Lo que no se puede hacer:** redirigir **HTTPS** de forma transparente. El navegador esperaba el certificado de `example.com` y recibiría el del portal: error de certificado. Por eso los sistemas operativos detectan el portal con una **petición HTTP de prueba** (Android: `connectivitycheck.gstatic.com/generate_204`; Apple: `captive.apple.com/hotspot-detect.html`). Si la respuesta no es la esperada, abren el navegador del portal. *Complementario:* la RFC 8910 permite anunciar la URL del portal por DHCP (opción 114).

### Topología

Una red de invitados 192.168.30.0/24 con gateway 192.168.30.1 en `lab-server`. En el TP7 esta red es el bridge `brvlan30` del SSID `UNCUYO-INVITADOS`. Para hacer el TP4 solo, podés usar un namespace `invitado` conectado por veth a un bridge `brvlan30`, con la misma técnica del TP3.

### Paso 1 · DHCP y DNS para invitados

Agregá a la configuración de dnsmasq (con `bind-interfaces`, como en el TP1):

```ini
interface=brvlan30
dhcp-range=set:invitados,192.168.30.100,192.168.30.199,255.255.255.0,30m
dhcp-option=tag:invitados,option:router,192.168.30.1
dhcp-option=tag:invitados,option:dns-server,192.168.30.1
server=1.1.1.1
```

### Paso 2 · Firewall con lista de autorizados

La pieza central es un **set** de nftables con vencimiento:

```text
table inet tp7 {
  set autorizados {
    type ipv4_addr
    flags timeout
    timeout 1h                      # el "login" vence en 1 hora
  }
  chain prerouting {
    type nat hook prerouting priority dstnat;
    iifname "brvlan30" ip saddr != @autorizados tcp dport 80 dnat ip to 192.168.30.1:8080
  }
  chain forward {
    type filter hook forward priority filter; policy drop;
    ct state established,related accept
    iifname "brvlan30" oifname "enp1s0" ip saddr @autorizados accept
    counter log prefix "TP7-DROP "
  }
  chain postrouting {
    type nat hook postrouting priority srcnat;
    oifname "enp1s0" masquerade
  }
}
```

Leela en voz alta: “Si viene de invitados, **no** está autorizado y va al puerto 80, cambiá el destino al portal. Hacia Internet sólo pasan los autorizados. Lo demás se descarta y se registra.” Archivo completo (con las VLAN del TP7): `configs/nftables-tp7.conf`.

### Paso 3 · El portal

`configs/portal.py` es un portal **didáctico** de 25 líneas: sirve una página y, en `/aceptar`, ejecuta `nft add element inet tp7 autorizados { <IP del cliente> }`.

```bash
sudo install -D configs/portal.py /opt/portal/portal.py
sudo python3 /opt/portal/portal.py &        # escucha en 192.168.30.1:8080
```

### Paso 4 · Experimento completo (desde el cliente invitado)

**Salida real:**

| # | Prueba | Resultado |
|---|---|---|
| 1 | `curl http://example.com` | `<h1>Wi-Fi Invitados UNCuyo</h1>…` → **el portal**, no example.com |
| 2 | `curl https://example.com` | `000 (Connection timed out)` → HTTPS no se redirige, se descarta |
| 3 | `ping 1.1.1.1` | bloqueado |
| 4 | `curl http://example.com/aceptar` | `Acceso concedido`; el set muestra `elements = { 192.168.30.161 expires 59m59s… }` |
| 5 | `curl http://example.com` | `<title>Example Domain</title>` → el sitio real |
| 6 | `curl https://example.com` | `200` |

```bash
sudo nft list set inet tp7 autorizados        # ver quién está autorizado y cuánto le queda
```

### Preguntas de análisis

1. En la captura del paso 1, ¿qué IP de destino tiene el paquete que sale del cliente? ¿Y el que llega al portal? ¿Dónde se hizo el cambio?
2. ¿Por qué el paso 2 termina en *timeout* y no en una página de error?
3. ¿Qué pasaría si el portal autorizara por **MAC** en lugar de IP? ¿Es más seguro? Pensá en que ambas se pueden falsificar.
4. El DNS del invitado funciona **antes** de aceptar. ¿Por qué hace falta que funcione? (Pista: sin DNS, ¿habría petición HTTP que redirigir?)
5. ¿Qué rol cumple el `timeout 1h` del set? ¿Cómo lo reemplaza un portal comercial?

### Errores típicos

| Síntoma | Causa |
|---|---|
| El portal no aparece | Regla DNAT sobre la interfaz equivocada, o portal escuchando en otra IP/puerto |
| Después de aceptar sigue apareciendo el portal | La IP no entró al set (el portal no corre como root) o el set está en otra tabla |
| Invitado sin IP | dnsmasq sin `interface=brvlan30`, o el bridge no existe al iniciar dnsmasq |
| Autorizado pero sin Internet | Falta masquerade o `ip_forward = 0` |

---

## TP5 · Wi-Fi empresarial: 802.1X, EAP y RADIUS

### El modelo 802.1X

| Rol | Quién es en el laboratorio | Qué hace |
|---|---|---|
| **Supplicant** | `wpa_supplicant` en el namespace del cliente | Presenta credenciales usando EAP |
| **Authenticator** | `hostapd` (el AP) | **No** conoce contraseñas: bloquea el puerto hasta que RADIUS diga que sí, y reenvía EAP |
| **Authentication Server** | FreeRADIUS | Verifica credenciales y devuelve Accept/Reject (+ atributos, + claves) |

Dos tramos, dos protocolos: **cliente ↔ AP: EAPOL** (EAP sobre 802.11) y **AP ↔ RADIUS: RADIUS** (UDP 1812), que lleva el EAP en atributos `EAP-Message`.

**PEAP-MSCHAPv2**, el método de este TP y el más común con usuario/contraseña: el cliente arma un **túnel TLS** con el servidor (valida su certificado) y dentro del túnel autentica con usuario y contraseña. Al final, RADIUS entrega al AP las claves `MS-MPPE-Send/Recv-Key`, de donde sale la **PMK**. Con la PMK, AP y cliente hacen el mismo 4-way handshake del TP6. **Cada usuario obtiene claves propias**, a diferencia de WPA2-PSK.

### Parte A · FreeRADIUS con `radtest` (valida sólo RADIUS)

Agregá usuarios **al principio** de `/etc/freeradius/3.0/mods-config/files/authorize`, antes de cualquier entrada `DEFAULT`:

```text
alumno1   Cleartext-Password := "alumno123"
docente1  Cleartext-Password := "docente123"
```

```bash
sudo freeradius -XC | tail -1          # "Configuration appears to be OK"
sudo systemctl restart freeradius
radtest alumno1 alumno123  127.0.0.1 0 testing123
radtest alumno1 incorrecta 127.0.0.1 0 testing123
```

**Salida real:**

```text
Sent Access-Request Id 239 from 0.0.0.0:55852 to 127.0.0.1:1812 length 77
Received Access-Accept Id 239 from 127.0.0.1:1812 to 127.0.0.1:55852 length 20
Received Access-Reject Id 22 from 127.0.0.1:1812 to 127.0.0.1:42708 length 20
```

`radtest` simula al AP, pero con **PAP**: una sola pregunta y una sola respuesta, sin EAP. `testing123` es el secreto compartido por defecto para `localhost` (`clients.conf`): en producción se cambia.

### Parte B · 802.1X real con AP virtual (requiere el TP6)

AP WPA2-Enterprise (`configs/hostapd-tp5-eap.conf` → `/etc/hostapd/tp5-eap.conf`). Si seguís el orden recomendado, el namespace `cliente` y las radios ya existen del TP6; antes, detené el AP del TP6 (`sudo pkill hostapd; sudo ip netns exec cliente pkill wpa_supplicant`):

```ini
interface=wlan0
driver=nl80211
ssid=UNCUYO-EDU
hw_mode=g
channel=1
ieee8021x=1
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP
own_ip_addr=127.0.0.1
nas_identifier=ap-lab
auth_server_addr=127.0.0.1
auth_server_port=1812
auth_server_shared_secret=testing123
ctrl_interface=/run/hostapd
```

Cliente (`configs/wpa-tp5-peap.conf` → `/root/tp5-wpa.conf`):

```ini
ctrl_interface=/run/wpa_supplicant
network={
  ssid="UNCUYO-EDU"
  key_mgmt=WPA-EAP
  eap=PEAP
  identity="alumno1"
  password="alumno123"
  phase2="auth=MSCHAPV2"
  ca_cert="/etc/ssl/certs/ssl-cert-snakeoil.pem"
}
```

`ca_cert` hace que el cliente **valide** el certificado del servidor RADIUS. En Debian, FreeRADIUS usa el certificado autofirmado *snakeoil*, que en el laboratorio funciona como su propia CA.

```bash
sudo tcpdump -i lo -w tp5-radius.pcap udp port 1812 &      # tramo AP <-> RADIUS
sudo tcpdump -i hwsim0 -w tp5-aire.pcap &                  # tramo cliente <-> AP
sudo hostapd -B -f /root/hostapd-tp5.log /etc/hostapd/tp5-eap.conf
sudo ip netns exec cliente wpa_supplicant -B -i wlan1 -c /root/tp5-wpa.conf -f /root/wpa-tp5.log
```

**Salida real del supplicant** (`wpa-tp5.log`):

```text
CTRL-EVENT-EAP-STARTED EAP authentication started
CTRL-EVENT-EAP-PROPOSED-METHOD vendor=0 method=4 -> NAK
CTRL-EVENT-EAP-PROPOSED-METHOD vendor=0 method=25
CTRL-EVENT-EAP-METHOD EAP vendor 0 method 25 (PEAP) selected
CTRL-EVENT-EAP-PEER-CERT depth=0 subject='/CN=localhost' ...
CTRL-EVENT-EAP-SUCCESS EAP authentication completed successfully
CTRL-EVENT-CONNECTED - Connection to 02:00:00:00:00:00 completed
```

**Salida real del AP** (`hostapd-tp5.log`):

```text
wlan0: EAPOL-4WAY-HS-COMPLETED 02:00:00:00:01:00
wlan0: STA 02:00:00:00:01:00 IEEE 802.1X: authenticated - EAP type: 25 (PEAP)
```

**Captura RADIUS real** (`tshark -r tp5-radius.pcap`): 20 paquetes. 10 rondas `Access-Request` / `Access-Challenge` y un `Access-Accept` final que contiene `MS-MPPE-Recv-Key` y `MS-MPPE-Send-Key`. Referencia: `capturas-referencia/tp5-peap-radius.pcap` y `tp5-8021x-aire.pcap`.

### Preguntas de análisis

1. El servidor propuso primero el método 4 (MD5) y el cliente respondió **NAK**. ¿Qué es un NAK en EAP y por qué el cliente no aceptó MD5?
2. `radtest` necesitó 1 intercambio; PEAP, 10. ¿Qué se está negociando en esas rondas?
3. ¿Por qué el `Access-Accept` de PEAP lleva claves (`MS-MPPE-*`) y el de `radtest` no?
4. ¿En qué tramo viajan las credenciales y cómo están protegidas? ¿Las podés leer en `tp5-aire.pcap`?
5. ¿Qué riesgo corre un cliente configurado **sin** `ca_cert`? Investigá los ataques de “AP gemelo” (*evil twin*).
6. Compará PEAP-MSCHAPv2 con EAP-TLS: ¿qué necesita cada uno del lado del cliente?

### Errores típicos

| Síntoma | Causa |
|---|---|
| `radtest` → `Access-Reject` con clave correcta | Usuario agregado **después** de una entrada `DEFAULT` que corta la búsqueda, o no reiniciaste FreeRADIUS |
| `radtest` sin respuesta | Secreto incorrecto (el servidor ignora el paquete) o servicio caído |
| Cliente en bucle `EAP-STARTED` | Certificado rechazado (`ca_cert` incorrecto) o fase 2 distinta |
| Hay que ver qué pasa por dentro | `sudo systemctl stop freeradius && sudo freeradius -X`: modo depuración, muestra cada paquete y cada decisión |

---

## TP6 · Wi-Fi completamente virtual

### Qué es `mac80211_hwsim`

Es un módulo del kernel que simula **radios 802.11 reales**. Usa la misma pila `mac80211` que una placa Wi-Fi física, así que hostapd y wpa_supplicant funcionan sin modificaciones. Además crea `hwsim0`, una interfaz de **monitor** que ve **todas** las tramas del “aire” con encabezado *radiotap*.

```text
                   "aire" simulado (lo ve hwsim0)
  ┌───────────── lab-server ─────────────────────────────────────┐
  │  wlan0 (phy0) ── hostapd = AP        02:00:00:00:00:00       │
  │  ┌─ namespace "cliente" ─┐                                   │
  │  │ wlan1 (phy1) ── wpa_supplicant    02:00:00:00:01:00       │
  │  └───────────────────────┘                                   │
  └──────────────────────────────────────────────────────────────┘
```

### Paso 1 · Radios y namespace

```bash
sudo modprobe mac80211_hwsim radios=3        # wlan0 (AP) + wlan1, wlan2 (clientes)
iw dev                                        # anotá qué phy tiene cada wlan
sudo ip link set hwsim0 up
sudo ip netns add cliente
sudo iw phy phy1 set netns name cliente       # se mueve el phy, no la interfaz
sudo ip -n cliente link set lo up
```

> Si recargás el módulo sin reiniciar, los phy cambian de número (`phy3`, `phy4`, …). Verificá siempre con `iw dev` o `iw phy`. Para empezar de cero: `sudo rmmod mac80211_hwsim`.

### Paso 2 · AP WPA2-PSK y cliente

`configs/hostapd-tp6-psk.conf` → copialo a `/etc/hostapd/tp6-psk.conf`:

```ini
interface=wlan0
driver=nl80211
ssid=WIFI-UNCUYO
hw_mode=g
channel=6
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=laboratorio123
ctrl_interface=/run/hostapd
```

`configs/wpa-tp6-psk.conf` → copialo a `/root/tp6-wpa.conf`:

```ini
ctrl_interface=/run/wpa_supplicant
network={
  ssid="WIFI-UNCUYO"
  psk="laboratorio123"
  key_mgmt=WPA-PSK
}
```

```bash
sudo tcpdump -i hwsim0 -w tp6.pcap &
sudo hostapd -B /etc/hostapd/tp6-psk.conf                 # → wlan0: AP-ENABLED
sudo ip netns exec cliente wpa_supplicant -B -i wlan1 -c /root/tp6-wpa.conf -f /root/wpa-tp6.log
sleep 10                                                   # la asociación tarda unos segundos
sudo ip netns exec cliente iw dev wlan1 link
```

**Salida real:**

```text
Connected to 02:00:00:00:00:00 (on wlan1)
	SSID: WIFI-UNCUYO
	freq: 2437
	signal: -30 dBm
	...
wlan1: WPA: Key negotiation completed with 02:00:00:00:00:00 [PTK=CCMP GTK=CCMP]
wlan1: CTRL-EVENT-CONNECTED - Connection to 02:00:00:00:00:00 completed
```

> Si `iw link` dice **`Not connected.`**, esperá unos segundos más y revisá el log de `wpa_supplicant` **antes** de concluir que falló. Si persiste, verificá que hostapd esté corriendo (`AP-ENABLED`), que el `phy` movido sea el correcto y que el archivo de configuración exista: `/etc/hostapd/` sólo aparece al instalar el paquete `hostapd`.

### Paso 3 · Análisis de la captura

```bash
tshark -r tp6.pcap -Y "wlan.fc.type_subtype==8" | head -2        # beacons
tshark -r tp6.pcap -Y "wlan.fc.type_subtype==4 or wlan.fc.type_subtype==5" | head   # probe req/resp
tshark -r tp6.pcap -Y "eapol or wlan.fc.type_subtype==0 or wlan.fc.type_subtype==1 or wlan.fc.type_subtype==11"
```

**Salida real** (la secuencia de conexión completa):

```text
02:00:00:00:00:00 → Broadcast         Beacon frame, BI=100, SSID="WIFI-UNCUYO"
02:00:00:00:01:00 → Broadcast         Probe Request, SSID=Wildcard (Broadcast)
02:00:00:00:00:00 → 02:00:00:00:01:00 Probe Response, SSID="WIFI-UNCUYO"
02:00:00:00:01:00 → 02:00:00:00:00:00 Authentication
02:00:00:00:00:00 → 02:00:00:00:01:00 Authentication
02:00:00:00:01:00 → 02:00:00:00:00:00 Association Request, SSID="WIFI-UNCUYO"
02:00:00:00:00:00 → 02:00:00:00:01:00 Association Response
02:00:00:00:00:00 → 02:00:00:00:01:00 EAPOL Key (Message 1 of 4)
02:00:00:00:01:00 → 02:00:00:00:00:00 EAPOL Key (Message 2 of 4)
02:00:00:00:00:00 → 02:00:00:00:01:00 EAPOL Key (Message 3 of 4)
02:00:00:00:01:00 → 02:00:00:00:00:00 EAPOL Key (Message 4 of 4)
```

| Trama | Subtipo | Qué hace |
|---|---|---|
| Beacon | 8 | El AP anuncia el SSID ~10 veces por segundo (BI = 100 TU ≈ 102 ms) |
| Probe Request/Response | 4 / 5 | Búsqueda activa del cliente |
| Authentication | 11 | “Open System” (en WPA2 no autentica nada todavía) |
| Association Request/Response | 0 / 1 | El cliente se une al BSS; se negocian capacidades y cifrado (RSN IE) |
| EAPOL 1–4 | — | **4-way handshake**: a partir de la PMK derivan la PTK (unicast) y entregan la GTK (grupo) |

### Extensión validada · WPA3-Personal (SAE)

`configs/hostapd-tp6-sae.conf` cambia `wpa_key_mgmt=SAE` y agrega `sae_password` e `ieee80211w=2` (PMF obligatorio). En el cliente: `key_mgmt=SAE`, `sae_password`, `ieee80211w=2`. **Salida real:** la conexión se completa. En la captura, la autenticación ya no son 2 tramas “Open System” sino **4 tramas SAE** (Commit y Confirm en cada sentido), seguidas del 4-way handshake. Referencia: `capturas-referencia/tp6-wpa3-sae-aire.pcap`.

### Preguntas de análisis

1. ¿Qué campos del Beacon permiten al cliente saber que la red usa WPA2 y CCMP? (Buscá el *RSN Information Element*).
2. En WPA2-PSK, las tramas “Authentication” no autentican a nadie. ¿Dónde se prueba realmente que el cliente conoce la clave?
3. Con la captura de los 4 mensajes EAPOL y un diccionario, un atacante puede intentar adivinar una PSK débil sin estar conectado. ¿Por qué? ¿Qué cambia SAE (WPA3)?
4. ¿Por qué el cliente tiene que estar en un namespace y no en `lab-client`?

---

## TP7 · Integrador

### Consigna

La Universidad tiene docentes, estudiantes e invitados. Diseñá, implementá y documentá una infraestructura inalámbrica que ofrezca: autenticación 802.1X para la comunidad, **VLAN asignada dinámicamente según el usuario**, portal cautivo para invitados, DHCP y DNS por red, salida a Internet con NAT y aislamiento entre redes con firewall.

### Arquitectura validada

```text
 SSID UNCUYO-EDU (WPA2-Enterprise)          SSID UNCUYO-INVITADOS (abierto)
   alumno1  ──► RADIUS: VLAN 10               invitado ──► bss wlan0_1
   docente1 ──► RADIUS: VLAN 20
          │                                            │
     hostapd (wlan0, dynamic_vlan)                     │
      ├─ wlan0.10 ─► brvlan10  192.168.10.1/24         │
      └─ wlan0.20 ─► brvlan20  192.168.20.1/24     brvlan30 192.168.30.1/24
                           │                            │
         dnsmasq: DHCP + DNS por VLAN (bind-interfaces, tags)
         nftables: forward policy drop · NAT · portal (set autorizados)
         FreeRADIUS: usuarios + atributos de VLAN
                           │
                        enp1s0 ─► Internet
```

| Red | VLAN | Bridge / gateway | Acceso |
|---|---|---|---|
| Alumnos | 10 | `brvlan10` · 192.168.10.1 | Internet |
| Docentes | 20 | `brvlan20` · 192.168.20.1 | Internet + red de alumnos |
| Invitados | 30 | `brvlan30` · 192.168.30.1 | Sólo el portal hasta aceptar; después, Internet |

### Paso 1 · RADIUS decide la VLAN

La VLAN viaja en tres atributos RADIUS estándar (RFC 3580). En `authorize`, al principio:

```text
alumno1   Cleartext-Password := "alumno123"
          Tunnel-Type = VLAN,
          Tunnel-Medium-Type = IEEE-802,
          Tunnel-Private-Group-Id = "10"

docente1  Cleartext-Password := "docente123"
          Tunnel-Type = VLAN,
          Tunnel-Medium-Type = IEEE-802,
          Tunnel-Private-Group-Id = "20"
```

`radtest docente1 docente123 127.0.0.1 0 testing123` → **salida real:**

```text
Received Access-Accept ...
	Tunnel-Type:0 = VLAN
	Tunnel-Medium-Type:0 = IEEE-802
	Tunnel-Private-Group-Id:0 = "20"
```

### Paso 2 · ⚠ El detalle que hace fallar a casi todos: PEAP y el túnel interno

Con `radtest` los atributos aparecen, pero **con PEAP el AP no los recibe**. En la validación, hostapd registró:

```text
IEEE 802.1X: authentication server did not include required VLAN ID in Access-Accept
```

**Por qué:** en PEAP, el usuario se autentica **dentro del túnel TLS**, que FreeRADIUS procesa en el sitio virtual `inner-tunnel`. Ahí se agregan los atributos de VLAN, pero el `Access-Accept` que viaja al AP se arma en el sitio **externo** (`default`), que no los tiene. **Solución** (FreeRADIUS 3.2): al principio de `post-auth` en `/etc/freeradius/3.0/sites-available/inner-tunnel`:

```text
post-auth {
	# llevar la VLAN asignada en el túnel interno al Access-Accept externo
	update outer.session-state {
		&Tunnel-Type := &reply:Tunnel-Type
		&Tunnel-Medium-Type := &reply:Tunnel-Medium-Type
		&Tunnel-Private-Group-Id := &reply:Tunnel-Private-Group-Id
	}
	...
```

El sitio `default` ya copia `session-state` al `Access-Accept` final (`&reply: += &session-state:`). Verificá con `freeradius -XC` y reiniciá.

### Paso 3 · hostapd con VLAN dinámica y dos SSIDs

`/etc/hostapd/tp7.vlan` (formato: `VID  interfaz  bridge`):

```text
10 wlan0.10 brvlan10
20 wlan0.20 brvlan20
```

Al final de la configuración del TP5 (archivo completo: `configs/hostapd-tp7-multi.conf` → `/etc/hostapd/tp7-multi.conf`):

```ini
dynamic_vlan=2                     # 2 = obligatoria: sin VLAN en el Accept, se rechaza
vlan_file=/etc/hostapd/tp7.vlan

bss=wlan0_1                        # segundo SSID en la misma radio
ssid=UNCUYO-INVITADOS
bridge=brvlan30                    # el bridge debe existir antes de iniciar hostapd
ctrl_interface=/run/hostapd
```

```bash
sudo ip link add brvlan30 type bridge && sudo ip link set brvlan30 up
sudo hostapd -B -f /root/hostapd-tp7.log /etc/hostapd/tp7-multi.conf
iw dev | grep -E "Interface|ssid"     # wlan0 (UNCUYO-EDU), wlan0_1 (UNCUYO-INVITADOS), wlan0.10, wlan0.20
sudo ip addr add 192.168.10.1/24 dev brvlan10
sudo ip addr add 192.168.20.1/24 dev brvlan20
sudo ip addr add 192.168.30.1/24 dev brvlan30
```

hostapd crea `wlan0.10/brvlan10` y `wlan0.20/brvlan20`. `dynamic_vlan=1` aceptaría clientes sin VLAN; con `2`, un usuario al que RADIUS no le asigna VLAN **no entra**, lo cual es más seguro.

### Paso 4 · DHCP y DNS por VLAN

`configs/dnsmasq-tp7.conf` usa **etiquetas** (`set:` / `tag:`) para dar a cada red su rango, su gateway y su DNS:

```ini
bind-interfaces
interface=brvlan10
interface=brvlan20
interface=brvlan30
except-interface=lo
domain=campus.lab
dhcp-range=set:alumnos,192.168.10.100,192.168.10.199,255.255.255.0,1h
dhcp-range=set:docentes,192.168.20.100,192.168.20.199,255.255.255.0,1h
dhcp-range=set:invitados,192.168.30.100,192.168.30.199,255.255.255.0,30m
dhcp-option=tag:alumnos,option:router,192.168.10.1
dhcp-option=tag:docentes,option:router,192.168.20.1
dhcp-option=tag:invitados,option:router,192.168.30.1
dhcp-option=tag:alumnos,option:dns-server,192.168.10.1
dhcp-option=tag:docentes,option:dns-server,192.168.20.1
dhcp-option=tag:invitados,option:dns-server,192.168.30.1
address=/portal.campus.lab/192.168.10.1
server=1.1.1.1
```

Los clientes en namespaces piden IP con `dhclient`. Para que el DNS que reciben no pise el del sistema, creá antes `/etc/netns/<ns>/resolv.conf` (vacío): `ip netns exec` lo monta como `/etc/resolv.conf` del namespace.

### Paso 5 · Conectar los clientes

```bash
# segundo cliente inalámbrico (docente) en su propio namespace
sudo ip netns add cliente2
sudo iw phy phy2 set netns name cliente2        # verificá el número con iw dev
sudo ip -n cliente2 link set lo up
sed -e 's/identity="alumno1"/identity="docente1"/; s/password="alumno123"/password="docente123"/' \
    /root/tp5-wpa.conf > /root/tp7-docente.conf

for ns in cliente cliente2; do sudo mkdir -p /etc/netns/$ns; sudo touch /etc/netns/$ns/resolv.conf; done
sudo ip netns exec cliente  wpa_supplicant -B -i wlan1 -c /root/tp5-wpa.conf     -f /root/wpa-alumno.log
sudo ip netns exec cliente2 wpa_supplicant -B -i wlan2 -c /root/tp7-docente.conf -f /root/wpa-docente.log
sleep 10
sudo ip netns exec cliente  dhclient -v wlan1
sudo ip netns exec cliente2 dhclient -v wlan2
grep "VLAN ID" /root/hostapd-tp7.log          # → VLAN ID 10 y VLAN ID 20
```

Para el invitado: `configs/wpa-invitado.conf` (SSID abierto, `key_mgmt=NONE`) en un tercer namespace, o reutilizá `cliente` después de desconectarlo de UNCUYO-EDU.

### Paso 6 · Firewall y portal

Cargá `configs/nftables-tp7.conf` (forward `policy drop`, reglas por VLAN, set `autorizados`, DNAT del portal, masquerade) con `sudo nft -f`, habilitá forwarding (`sysctl -w net.ipv4.ip_forward=1`) y levantá el portal del TP4. Conviene cargar el firewall **antes** de conectar a los invitados.

### Paso 7 · Matriz de pruebas (resultados reales de la validación)

| Prueba | Resultado |
|---|---|
| `alumno1` se conecta a UNCUYO-EDU | hostapd: `RADIUS: VLAN ID 10` · DHCP: `192.168.10.161` |
| `docente1` se conecta a UNCUYO-EDU | hostapd: `RADIUS: VLAN ID 20` · DHCP: `192.168.20.160` |
| DNS en la VLAN 10 | `nameserver 192.168.10.1` · `dig portal.campus.lab` → `192.168.10.1` |
| Alumno → gateway | OK |
| Alumno → Internet (`ping 1.1.1.1`, `curl https://example.com`) | OK · `200` |
| Alumno → docente | **bloqueado**, y el log muestra `TP7-DROP IN=brvlan10 OUT=brvlan20 SRC=192.168.10.161 DST=192.168.20.160` |
| Docente → alumno | OK |
| Docente → Internet | OK |
| Invitado antes de aceptar | HTTP → portal · HTTPS → timeout · ping → bloqueado |
| Invitado después de aceptar | HTTP → Example Domain · HTTPS → `200` |

Referencia: `capturas-referencia/tp7-vlan-dinamica-radius.pcap`. Cada `Access-Accept` lleva `User-Name` y su `Tunnel-Private-Group-Id` (10 o 20).

### Entregables del TP7

1. Diagrama de la arquitectura con VLANs, bridges, IPs y servicios.
2. Todas las configuraciones (hostapd, archivo de VLAN, FreeRADIUS, dnsmasq, nftables, portal).
3. Matriz de pruebas **propia**, con evidencia de cada fila.
4. Capturas: RADIUS con los atributos de VLAN, aire (EAPOL de ambos usuarios), DHCP en cada VLAN, un intento bloqueado con su línea de log.
5. Un análisis de seguridad: qué protege cada capa (802.1X, VLAN, firewall, portal) y qué **no** protege.

### Para ir más allá (opcional)

- Servicios persistentes: units de systemd para hostapd, el portal y la creación de bridges; nftables con `/etc/nftables.conf`.
- EAP-TLS con certificados de cliente (`make` en `/etc/freeradius/3.0/certs`).
- *Accounting* RADIUS (UDP 1813): ¿qué información registra el AP al conectar y desconectar?
- WPA3-Enterprise o SSID de invitados con WPA3-SAE (“Wi-Fi abierto” cifrado: OWE).

---

## 8. Troubleshooting general

**Método:** de abajo hacia arriba y un cambio por vez (presentación 04).

| Capa | Pregunta | Comando |
|---|---|---|
| Radio | ¿El AP está activo? ¿El cliente está asociado? | log de hostapd (`AP-ENABLED`), `iw dev wlan1 link`, `iw dev wlan0 station dump` |
| Autenticación | ¿EAP terminó bien? ¿RADIUS aceptó? | log de wpa_supplicant (`EAP-SUCCESS`), `freeradius -X` |
| VLAN | ¿El cliente cayó en la VLAN correcta? | log de hostapd (`VLAN ID`), `bridge link` |
| IP | ¿Recibió IP del rango de su VLAN? | `ip -n <ns> -br addr`, captura `dhcp` en el bridge |
| Gateway | ¿Llega a su gateway? | `ping 192.168.X.1` |
| Firewall | ¿Qué se está descartando? | `journalctl -k \| grep TP7-DROP`, contadores de `nft list ruleset` |
| NAT / salida | ¿Sale traducido por la WAN? | `tcpdump -n -i enp1s0` |
| DNS | ¿Resuelve? | `dig @<gateway> example.com` |

| Síntoma | Causa frecuente en este laboratorio |
|---|---|
| dnsmasq en `failed` al instalarlo | Puerto 53 ocupado por systemd-resolved: `bind-interfaces` + `interface=` |
| Perdí la conexión con la VM | `netplan apply` por SSH: usá `virsh console` |
| Desaparecieron las IPs de los bridges | Se reinició systemd-networkd (`netplan apply`) después de crearlas: volvé a asignarlas |
| El TP2 “funciona” con el router mal configurado | El cliente tiene su propia salida por `enp1s0`: revisá `ip route` |
| `Not connected.` en `iw link` | Consultaste demasiado pronto, hostapd no corre o se movió el phy equivocado |
| hostapd: `did not include required VLAN ID` | Falta copiar los atributos del `inner-tunnel` (TP7, paso 2) |
| El ping sigue andando tras borrar el NAT | Entrada de conntrack: lanzá un ping nuevo |

---

## 9. Anexos

### 9.1 Archivos de esta carpeta

| Archivo | Uso |
|---|---|
| `configs/hostapd-tp6-psk.conf`, `wpa-tp6-psk.conf` | TP6 · WPA2-PSK |
| `configs/hostapd-tp6-sae.conf`, `wpa-tp6-sae.conf` | TP6 · WPA3-SAE |
| `configs/hostapd-tp5-eap.conf`, `wpa-tp5-peap.conf` | TP5 · 802.1X PEAP |
| `configs/hostapd-tp7-multi.conf`, `hostapd-tp7.vlan` | TP7 · VLAN dinámica + SSID invitados (copiar como `/etc/hostapd/tp7.vlan`) |
| `configs/freeradius-fragmentos.txt` | TP5/TP7 · usuarios con VLAN + bloque `post-auth` del `inner-tunnel` |
| `configs/dnsmasq-tp7.conf` | TP4/TP7 · DHCP/DNS por VLAN |
| `configs/nftables-tp7.conf` | TP3/TP4/TP7 · firewall, portal y NAT |
| `configs/portal.py`, `wpa-invitado.conf` | TP4 · portal didáctico y cliente del SSID abierto |
| `capturas-referencia/*.pcap` | Capturas reales de la validación para comparar con las tuyas |
| `GUIA-COMPLEMENTARIA-MIKROTIK.md`, `configs/mikrotik/*.rsc` | Actividad complementaria (optativa): TP1 a TP4 sobre MikroTik RouterOS |

### 9.2 Filtros útiles de Wireshark/tshark

| Qué | Filtro |
|---|---|
| DHCP | `dhcp` |
| DNS | `dns` |
| Etiquetas 802.1Q | `vlan` · `vlan.id == 10` |
| Beacons de un SSID | `wlan.fc.type_subtype == 8 && wlan.ssid == "WIFI-UNCUYO"` |
| Autenticación / asociación | `wlan.fc.type_subtype == 11` · `wlan.fc.type_subtype == 0` |
| 4-way handshake | `eapol` |
| EAP (802.1X) | `eap` |
| RADIUS | `radius` · `radius.code == 2` (Accept) · `radius.code == 11` (Challenge) |
| VLAN asignada por RADIUS | `radius.code == 2` y, en el detalle del paquete, el AVP `Tunnel-Private-Group-Id` |

### 9.3 Relación con la teoría

| TP | Presentaciones |
|---|---|
| TP1 | 01 DHCP · 02 DNS |
| TP2 | 03 Routing · 04 NAT y troubleshooting |
| TP3–TP7 | 04 (troubleshooting, firewall, NAT) · 05 (integración); el resto está en esta guía |
