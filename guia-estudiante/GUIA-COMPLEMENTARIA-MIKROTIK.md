# Guía · Actividad complementaria con MikroTik RouterOS

**Materia:** Redes Inalámbricas · ITU · Universidad Nacional de Cuyo
**Versión:** 05/10/2026 · Enunciado: `../laboratorio/enunciados/COMPLEMENTARIA-MIKROTIK.md`

En los TP1 a TP4 armaste, con Linux, los servicios que cualquier red Wi-Fi de campus necesita: DHCP, DNS, NAT, VLANs, firewall y portal cautivo. En la práctica, esos servicios suelen correr en un **router dedicado**. Esta actividad repite lo mismo en **MikroTik RouterOS**, muy usado en ISP, empresas y redes inalámbricas, para que veas que **los conceptos son los mismos y sólo cambia la sintaxis**.

| Concepto | Linux (TP1–TP4) | RouterOS |
|---|---|---|
| IP de una interfaz | netplan / `ip addr` | `/ip address` |
| DHCP | dnsmasq `dhcp-range` | `/ip pool` + `/ip dhcp-server` + `/ip dhcp-server network` |
| DNS con caché y registros locales | dnsmasq `address=/…/` | `/ip dns` + `/ip dns static` |
| NAT | nftables `masquerade` | `/ip firewall nat … action=masquerade` |
| Firewall | nftables cadenas `input` / `forward` | `/ip firewall filter` cadenas `input` / `forward` |
| Subinterfaz VLAN | `ip link add … type vlan id 10` | `/interface vlan add … vlan-id=10` |
| Portal cautivo | DNAT + set con vencimiento + `portal.py` | `/ip hotspot` (crea sus propias reglas) |

> **Todo lo que aparece como “salida real” se obtuvo al validar esta guía** con RouterOS **7.24.5** (CHR) sobre KVM/libvirt, con los clientes en Debian 12. Tus MAC, IPs dinámicas y contadores serán distintos, pero la **forma** del resultado debe coincidir. Los archivos `configs/mikrotik/mk*.rsc` son la configuración validada, parte por parte, y en `capturas-referencia/` están `mk-vlan-trunk.pcap` y `mk-hotspot-login.pcap`.

---

## 0. Antes de empezar

### 0.1 El MikroTik virtual (CHR)

El **CHR** (*Cloud Hosted Router*) es RouterOS para máquinas virtuales. Se descarga gratis y sin licencia funciona sin límite de tiempo, con la **velocidad de subida limitada a 1 Mbps por interfaz**. Alcanza de sobra para el laboratorio. La VM se crea según `../laboratorio/README.md`, sección *Actividad complementaria MikroTik*.

| Interfaz | Red | Uso |
|---|---|---|
| `ether1` | `default` | WAN. De fábrica, el CHR pide IP por DHCP en `ether1` (`/ip dhcp-client`) |
| `ether2` | `lab1` | LAN sin etiqueta + trunk de las VLAN 10, 20 y 30 |

### 0.2 Primer acceso

El CHR **no usa la consola serie**: abrí la consola gráfica con `virt-viewer lab-mikrotik` (o desde virt-manager). Usuario `admin`, contraseña vacía. Respondé `n` a la licencia y definí una contraseña:

```text
  MikroTik RouterOS 7.24.5 (c) 1999-2026       https://www.mikrotik.com/

Do you want to see the software license? [Y/n]: n

Change your password (Ctrl-C to skip)
new password> *********
repeat new password> *********

Password changed
[admin@CHR] >
```

Una vez configurada la Parte 1, administrás el router **desde la LAN**, que es lo correcto:

- **libvirt:** el host está en `lab1` como `10.10.10.254`, así que desde el host: `ssh admin@10.10.10.1` o el navegador en `http://10.10.10.1` (**WebFig**, la interfaz web).
- **VirtualBox:** el host no está en la red interna; usá `ssh admin@10.10.10.1` desde `lab-client`.
- **WinBox** (la aplicación de escritorio de MikroTik, para Windows) muestra los mismos menús que WebFig. *No se validó en esta guía*.

### 0.3 Cómo leer los comandos de RouterOS

```text
/ip address add address=10.10.10.1/24 interface=ether2
└── menú ──┘ └acción┘ └──────── parámetros ───────────┘
```

- `print` lista, `add` agrega, `set` modifica, `remove` borra, `export` muestra la configuración como comandos.
- Tab completa, `?` ayuda. En WebFig/WinBox, el menú `/ip address` es **IP → Addresses**.
- Los `.rsc` de `configs/mikrotik/` se pueden aplicar subiéndolos y con `/import`, pero **escribí los comandos vos**: el objetivo es entenderlos.

### 0.4 Preparar las VMs Linux

```bash
# lab-server: un solo servidor DHCP en lab1, y ese ahora es el MikroTik
sudo systemctl disable --now dnsmasq
```

`lab-server` mantiene `enp2s0 = 10.10.10.10/24` (netplan del TP1). Si después del TP2 alguna VM quedó en `lab2`, volvela a `lab1` desde el host:

```bash
virsh domiflist lab-client                                 # ver en qué red está cada interfaz
virt-xml lab-client --edit 1 --network network=lab1 --update
virt-xml lab-server --edit 2 --network network=lab1 --update
```

---

## Parte 1 · LAN, DHCP y DNS (equivale al TP1)

```text
/system identity set name=lab-mikrotik

/ip address add address=10.10.10.1/24 interface=ether2 comment="LAN lab1"

/ip pool add name=pool-lan ranges=10.10.10.100-10.10.10.199
/ip dhcp-server add name=dhcp-lan interface=ether2 address-pool=pool-lan lease-time=1h
/ip dhcp-server network add address=10.10.10.0/24 gateway=10.10.10.1 dns-server=10.10.10.1 domain=lab.local

/ip dns set servers=1.1.1.1,8.8.8.8 allow-remote-requests=yes
/ip dns static add name=router.lab.local address=10.10.10.1
/ip dns static add name=server.lab.local address=10.10.10.10
```

Fijate que el DHCP de RouterOS se arma en **tres piezas**: el *pool* (qué direcciones), el *server* (en qué interfaz) y el *network* (qué opciones se entregan: gateway, DNS, dominio). En dnsmasq las tres cosas estaban en `dhcp-range` y `dhcp-option`.

`allow-remote-requests=yes` convierte al router en servidor DNS para los clientes. Sin eso, sólo resuelve para sí mismo.

**PRUEBA 1 · Salida real** en el MikroTik, después de que el cliente pidió IP:

```text
[admin@lab-mikrotik] > /ip dhcp-server lease print
Columns: ADDRESS, MAC-ADDRESS, HOST-NAME, SERVER, STATUS, LAST-SEEN
#   ADDRESS       MAC-ADDRESS        HOST-NAME  SERVER    STATUS  LAST-SEEN
0 D 10.10.10.198  52:54:00:FF:EA:84  localhost  dhcp-lan  bound   18s
```

La `D` indica que es una concesión **dinámica**. En el cliente: `ip -br addr`, `ip route` (por defecto vía `10.10.10.1`) y `resolvectl status` (DNS `10.10.10.1`, dominio `lab.local`).

**PRUEBA 2 · Salida real** desde el cliente:

```text
$ dig +noall +answer +stats server.lab.local @10.10.10.1
server.lab.local.	86400	IN	A	10.10.10.10
;; SERVER: 10.10.10.1#53(10.10.10.1) (UDP)

$ dig +short example.com
172.66.147.243
104.20.23.154
```

El TTL `86400` (1 día) es el de los registros estáticos de RouterOS.

---

## Parte 2 · NAT y protección del router (equivale al TP2)

```text
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment="NAT LAN -> WAN"

/ip firewall filter
add chain=input connection-state=established,related action=accept comment="input: respuestas"
add chain=input connection-state=invalid action=drop comment="input: invalidos"
add chain=input protocol=icmp action=accept comment="input: ping"
add chain=input in-interface=ether1 action=drop comment="input: nada mas desde la WAN"
```

### ⚠ Te podés quedar afuera

La cadena `input` filtra el tráfico **dirigido al router**. Eso incluye tu sesión de administración. Si estás conectado por SSH o WebFig a la IP de `ether1`, **la última regla corta tu propia sesión** al aplicarla. Por eso conviene administrar desde la LAN (sección 0.2). En un equipo remoto real se usa el **Safe Mode** de RouterOS (Ctrl+X en la terminal): si la sesión se corta, el router deshace los cambios.

### Por qué hace falta la cadena `input`

**Salida real** desde el host, consultando a la IP WAN del router (`192.168.122.224` en la validación), **antes** de la última regla:

```text
$ dig +noall +answer example.com @192.168.122.224
example.com.		206	IN	A	172.66.147.243
example.com.		206	IN	A	104.20.23.154
$ curl -s -o /dev/null -w "%{http_code}\n" http://192.168.122.224/
200
```

El router respondía DNS y mostraba su WebFig **a cualquiera del lado de la WAN**. Un resolvedor DNS abierto en Internet se usa para ataques de amplificación. **Después** de la regla:

```text
$ dig example.com @192.168.122.224
;; communications error to 192.168.122.224#53: timed out
$ dig +noall +answer server.lab.local @10.10.10.1       # por la LAN, sigue funcionando
server.lab.local.	86400	IN	A	10.10.10.10
```

**PRUEBA 3 · Salida real** del contador de NAT después de navegar desde el cliente:

```text
[admin@lab-mikrotik] > /ip firewall nat print stats
Columns: CHAIN, ACTION, BYTES, PACKETS
# CHAIN   ACTION      BYTES  PACKETS
;;; NAT LAN -> WAN
0 srcnat  masquerade    406        5
```

¿Por qué tan pocos paquetes? Igual que en nftables, la regla de NAT se evalúa sólo con el **primer paquete de cada conexión**; el resto se traduce por conntrack.

---

## Parte 3 · VLANs y firewall entre VLANs (equivale al TP3)

En el TP3 hiciste un router *on a stick* con `eth0.10` y `eth0.20`. En RouterOS es lo mismo: interfaces VLAN sobre `ether2`, que pasa a ser un **trunk** (sigue llevando la LAN sin etiqueta y, además, las VLANs etiquetadas).

```text
/interface vlan
add name=vlan10 vlan-id=10 interface=ether2 comment="Alumnos"
add name=vlan20 vlan-id=20 interface=ether2 comment="Docentes"

/ip address
add address=192.168.10.1/24 interface=vlan10
add address=192.168.20.1/24 interface=vlan20

/interface list add name=LAN
/interface list member
add list=LAN interface=ether2
add list=LAN interface=vlan10
add list=LAN interface=vlan20

/ip firewall filter
add chain=forward connection-state=established,related action=accept comment="fwd: respuestas"
add chain=forward connection-state=invalid action=drop comment="fwd: invalidos"
add chain=forward in-interface=vlan20 out-interface=vlan10 action=accept comment="fwd: docentes -> alumnos"
add chain=forward in-interface-list=LAN out-interface=ether1 action=accept comment="fwd: redes internas -> Internet"
add chain=forward action=drop comment="fwd: todo lo demas"
```

Diferencia con nftables: en RouterOS **las cadenas no tienen política**. Todo lo que no coincide con ninguna regla se **acepta**. El `policy drop` del TP3 se reemplaza por una **última regla `drop` sin condiciones**. Las reglas se evalúan en orden: si la pusieras primera, cortaría todo.

Las **interface lists** (`LAN`) son el equivalente a los conjuntos de interfaces de nftables (`iifname { … }`): agregás una VLAN a la lista y todas las reglas que la usan la incluyen.

### Los equipos en `lab-server`

```bash
for v in 10 20; do
  sudo ip link add link enp2s0 name enp2s0.$v type vlan id $v
  sudo ip netns add pc$v
  sudo ip link set enp2s0.$v netns pc$v
  sudo ip -n pc$v link set lo up
  sudo ip -n pc$v link set enp2s0.$v up
  sudo ip -n pc$v addr add 192.168.$v.10/24 dev enp2s0.$v
  sudo ip -n pc$v route add default via 192.168.$v.1
done
```

**PRUEBA 5 · Salida real:**

```text
pc20 -> pc10:   2 packets transmitted, 1 received, 50% packet loss     (el 1.º se pierde mientras resuelve ARP)
pc10 -> pc20:   2 packets transmitted, 0 received, 100% packet loss
pc10 -> 1.1.1.1: rtt min/avg/max/mdev = 11.706/14.250/16.795/2.544 ms
```

**PRUEBA 6 · Salida real** (`sudo tcpdump -nn -e -i enp2s0 vlan and icmp` mientras `pc20` hace ping a `pc10`; referencia: `capturas-referencia/mk-vlan-trunk.pcap`):

```text
52:54:00:51:d0:dd > 52:54:00:e4:5e:19, ethertype 802.1Q (0x8100), length 102: vlan 20, p 0, ethertype IPv4 (0x0800), 192.168.20.10 > 192.168.10.10: ICMP echo request
52:54:00:e4:5e:19 > 52:54:00:51:d0:dd, ethertype 802.1Q (0x8100), length 102: vlan 10, p 0, ethertype IPv4 (0x0800), 192.168.20.10 > 192.168.10.10: ICMP echo request
52:54:00:51:d0:dd > 52:54:00:e4:5e:19, ethertype 802.1Q (0x8100), length 102: vlan 10, p 0, ethertype IPv4 (0x0800), 192.168.10.10 > 192.168.20.10: ICMP echo reply
52:54:00:e4:5e:19 > 52:54:00:51:d0:dd, ethertype 802.1Q (0x8100), length 102: vlan 20, p 0, ethertype IPv4 (0x0800), 192.168.10.10 > 192.168.20.10: ICMP echo reply
```

Cada paquete pasa **dos veces** por el trunk: sube al router con la etiqueta de la VLAN de origen y baja con la de la VLAN de destino. La MAC `52:54:00:e4:5e:19` es la de `ether2` del MikroTik.

**PRUEBA 7 · Salida real.** Con los contadores en cero (`/ip firewall filter reset-counters-all`), tres pings en cada caso: `pc20 → pc10`, `pc10 → pc20` y `pc10 → 1.1.1.1`:

```text
[admin@lab-mikrotik] > /ip firewall filter print stats where chain=forward
Flags: D - DYNAMIC
Columns: CHAIN, ACTION, BYTES, PACKETS
#   CHAIN    ACTION  BYTES  PACKETS
0 D forward  jump        0        0
1 D forward  jump        0        0
;;; fwd: respuestas
2   forward  accept    840       10
;;; fwd: invalidos
3   forward  drop        0        0
;;; fwd: docentes -> alumnos
4   forward  accept     84        1
;;; fwd: redes internas -> Internet
5   forward  accept     84        1
;;; fwd: todo lo demas
6   forward  drop      252        3
```

- Las reglas 4 y 5 cuentan **un solo paquete** cada una: el primero de cada conexión.
- Los otros 10 (2 pedidos + 3 respuestas, por cada uno de los dos pings que funcionan) entran por la regla 2, gracias a conntrack.
- Los 3 descartados son los pings de `pc10` a `pc20`.
- Las reglas `D` (dinámicas) las agrega el Hotspot de la Parte 4. Si todavía no lo configuraste, no aparecen.

---

## Parte 4 · Hotspot para invitados (equivale al TP4)

El **Hotspot** de RouterOS es un portal cautivo completo: intercepta HTTP, sirve la página de login, autentica (usuarios locales o RADIUS) y abre el acceso por cliente. Lo que en el TP4 armaste a mano con DNAT, un set con vencimiento y `portal.py`, acá lo arma el router.

```text
/interface vlan add name=vlan30 vlan-id=30 interface=ether2 comment="Invitados"
/ip address add address=192.168.30.1/24 interface=vlan30
/interface list member add list=LAN interface=vlan30

/ip pool add name=pool-invitados ranges=192.168.30.100-192.168.30.199
/ip dhcp-server add name=dhcp-invitados interface=vlan30 address-pool=pool-invitados lease-time=30m
/ip dhcp-server network add address=192.168.30.0/24 gateway=192.168.30.1 dns-server=192.168.30.1

/ip hotspot profile add name=hsprof-invitados hotspot-address=192.168.30.1 dns-name=portal.lab.local login-by=http-chap,http-pap,trial trial-uptime-limit=1h trial-uptime-reset=1d
/ip hotspot add name=hs-invitados interface=vlan30 address-pool=pool-invitados profile=hsprof-invitados disabled=no
/ip hotspot user add name=invitado1 password=invitado123 server=hs-invitados limit-uptime=1h
```

`login-by` define cómo se puede entrar: `http-chap` (la contraseña no viaja en claro), `http-pap` (viaja en claro) y `trial` (sin usuario: el equivalente al “Acepto” del TP4, limitado a 1 hora por día y por MAC).

### El invitado en `lab-server`

```bash
sudo ip link add link enp2s0 name enp2s0.30 type vlan id 30
sudo ip netns add invitado
sudo ip link set enp2s0.30 netns invitado
sudo ip -n invitado link set lo up
sudo ip -n invitado link set enp2s0.30 up
sudo mkdir -p /etc/netns/invitado && sudo touch /etc/netns/invitado/resolv.conf
sudo ip netns exec invitado dhclient -v enp2s0.30
```

`/etc/netns/invitado/resolv.conf` hace que el namespace tenga su propio `resolv.conf`, que `dhclient` (instalado en la sección 0.2 de la guía principal) llena con el DNS del MikroTik.

**PRUEBA 8 · Salida real** (antes del login):

```text
$ curl -s -i http://example.com | head -3
HTTP/1.1 302 Found
...
Location: http://portal.lab.local/login?dst=http%3A%2F%2Fexample.com%2F

$ curl -s -o /dev/null -w "%{http_code} %{errormsg}\n" https://example.com
000 OpenSSL SSL_connect: SSL_ERROR_SYSCALL in connection to example.com:443

$ ping -c2 1.1.1.1
2 packets transmitted, 0 received, +2 errors, 100% packet loss
```

Igual que en el TP4: HTTP se redirige, HTTPS no se puede redirigir sin romper TLS.

**PRUEBA 9 · Salida real.** Login por línea de comandos (el formulario de la página hace lo mismo):

```text
$ curl -s -o /dev/null -d "username=invitado1&password=invitado123" http://portal.lab.local/login

[admin@lab-mikrotik] > /ip hotspot active print
Columns: USER, ADDRESS, UPTIME, SESSION-TIME-LEFT
# USER       ADDRESS         UPTIME  SESSION-TIME-LEFT
0 invitado1  192.168.30.199  7s      59m53s

$ curl -s http://example.com | grep -o "<title>.*</title>"
<title>Example Domain</title>
$ curl -s -o /dev/null -w "https %{http_code}\n" https://example.com
https 200
$ ping -c2 192.168.10.10                 # hacia pc10 (alumnos)
2 packets transmitted, 0 received, 100% packet loss
```

El invitado autenticado sale a Internet pero **no** entra a las otras VLANs: lo bloquea la última regla de `forward` de la Parte 3.

**PRUEBA 10 · Salida real.** Después de `/ip hotspot active remove [find]`, el cliente vuelve a ser redirigido (`302`). Con el enlace *trial* de la página de login:

```text
[admin@lab-mikrotik] > /ip hotspot active print
# USER                 ADDRESS         UPTIME  SESSION-TIME-LEFT
0 T-52:54:00:51:D0:DD  192.168.30.199  1s      59m59s
```

El usuario *trial* se llama `T-` + la **MAC** del cliente: así el router controla la hora gratuita por equipo.

**PRUEBA 11 · Salida real** (login con `http-pap`, capturado en el trunk; referencia: `capturas-referencia/mk-hotspot-login.pcap`):

```text
$ sudo tcpdump -nn -A -i enp2s0 "vlan 30 and tcp port 80" | grep -o "username=[^ ]*"
username=invitado1&password=invitado123
```

Con `http-pap` la contraseña viaja **en claro**. Con `http-chap`, la página de login calcula en el navegador (JavaScript) un hash MD5 de la contraseña con un desafío que envía el router, y sólo viaja ese hash.

### Las reglas que creó el Hotspot

**Salida real** (recortada) de `/ip firewall nat print where dynamic=yes`:

```text
 1 D chain=dstnat action=jump jump-target=hotspot hotspot=from-client
 3 D chain=hotspot action=redirect to-ports=64872 protocol=udp dst-port=53
 7 D chain=hotspot action=jump jump-target=hs-unauth protocol=tcp hotspot=!auth
 9 D chain=hs-unauth action=redirect to-ports=64874 protocol=tcp dst-port=80
12 D chain=hs-unauth action=redirect to-ports=64875 protocol=tcp dst-port=443
```

La regla 9 es tu DNAT del TP4 (puerto 80 de los no autorizados hacia el portal). `hotspot=!auth` cumple el papel del set `autorizados`. La regla 3 intercepta el DNS de los clientes del Hotspot. La 12 intenta llevar el 443 a un portal HTTPS que no configuramos: por eso HTTPS falla en vez de mostrar un error de certificado.

---

## Errores típicos

| Síntoma | Causa |
|---|---|
| El cliente recibe IP de `10.10.10.x` pero de otro servidor | dnsmasq de `lab-server` sigue activo: dos DHCP en `lab1` |
| Se corta la sesión SSH/WebFig al cargar el firewall | Administrabas por `ether1` y la regla `input` de la WAN te dejó afuera. Entrá por la LAN o por la consola |
| Las VLANs se ven entre sí aunque está la regla `drop` | La regla quedó **antes** de las `accept` o falta: RouterOS acepta todo lo que no coincide |
| El invitado no obtiene IP | Falta `/ip dhcp-server` en `vlan30` o la subinterfaz está en otra VLAN |
| El invitado autenticado no navega | Falta `vlan30` en la lista `LAN` (la regla `forward` hacia Internet no lo incluye) |
| Descargas lentas desde los clientes | Límite de 1 Mbps del CHR sin licencia; es normal |

## Para cerrar

Completá la tabla de equivalencias del entregable con tus propias palabras. La pregunta de fondo es la de todos los TP: **qué decide cada componente** (quién entrega la IP, quién resuelve, quién traduce, quién separa y quién filtra). Si sabés eso, cambiar de Linux a RouterOS, o a cualquier otro fabricante, es cuestión de buscar dónde está cada menú.
