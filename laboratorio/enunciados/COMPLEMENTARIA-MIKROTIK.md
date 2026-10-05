# Actividad complementaria: el laboratorio sobre MikroTik RouterOS

> **Actividad complementaria (optativa).** No reemplaza a ningún TP. Repite los servicios de los TP1 a TP4 en un router de uso profesional, para comparar cómo se resuelve lo mismo en Linux y en RouterOS. Conviene hacerla **después del TP4**.

## Objetivos Pedagógicos
- Desplegar MikroTik RouterOS (*Cloud Hosted Router*, CHR) como router de la red del laboratorio.
- Configurar en RouterOS los servicios ya implementados en Linux: DHCP, DNS, NAT, VLANs, firewall entre VLANs y portal cautivo.
- Relacionar cada concepto con su equivalente en Linux (dnsmasq, nftables, `ip link … type vlan`, portal didáctico).
- Comprender la protección del propio router (cadena `input`) y el riesgo de dejarse afuera al aplicarla.
- Usar el **Hotspot** de RouterOS y analizar las reglas que crea por su cuenta.

## Topología
Se agrega una VM `lab-mikrotik` con dos interfaces. Las VMs `lab-server` y `lab-client` son las mismas de los TP1 a TP4, ambas conectadas a `lab1`.

```text
                     Internet
                        │ red "default" (DHCP del host)
                   ether1 (WAN)
                 [ lab-mikrotik ]  RouterOS CHR
                   ether2 (LAN, trunk)
                        │ red "lab1"
        ┌───────────────┴───────────────────────────┐
   lab-client                                   lab-server  enp2s0 = 10.10.10.10/24
   (sin etiqueta, DHCP 10.10.10.1xx)            ├─ enp2s0.10 → namespace pc10      192.168.10.10/24
                                                ├─ enp2s0.20 → namespace pc20      192.168.20.10/24
                                                └─ enp2s0.30 → namespace invitado  DHCP 192.168.30.1xx
```

| Red | VLAN | Uso | Gateway (MikroTik) |
|---|---|---|---|
| 10.10.10.0/24 | sin etiqueta | LAN del TP1/TP2 | 10.10.10.1 (`ether2`) |
| 192.168.10.0/24 | 10 | Alumnos | 192.168.10.1 (`vlan10`) |
| 192.168.20.0/24 | 20 | Docentes | 192.168.20.1 (`vlan20`) |
| 192.168.30.0/24 | 30 | Invitados con Hotspot | 192.168.30.1 (`vlan30`) |

## Consignas

### Parte 0: Preparación
1. Crea la VM `lab-mikrotik` según `laboratorio/README.md` (sección *Actividad complementaria MikroTik*).
2. En `lab-server`, **detén dnsmasq** (`systemctl disable --now dnsmasq`). En `lab1` sólo puede haber un servidor DHCP.
3. Verifica que `lab-server` (`enp2s0`) y `lab-client` estén en la red `lab1`. Si quedaron en `lab2` después del TP2, cámbialos.
4. Entra a la consola del MikroTik como `admin` (sin contraseña) y define una contraseña.

### Parte 1: LAN, DHCP y DNS (equivale al TP1)
1. Asigna `10.10.10.1/24` a `ether2`.
2. Crea un servidor DHCP en `ether2` con el rango `10.10.10.100–199`, gateway y DNS `10.10.10.1` y dominio `lab.local`.
3. Habilita el DNS del router para los clientes, con reenvío a un DNS público, y crea los registros estáticos `router.lab.local` y `server.lab.local`.
4. **PRUEBA 1:** `lab-client` obtiene IP por DHCP. Muestra la concesión en el cliente y en el MikroTik (`/ip dhcp-server lease print`).
5. **PRUEBA 2:** Desde `lab-client`, resuelve `server.lab.local` y `example.com` con `dig`, indicando qué servidor respondió.

### Parte 2: NAT y protección del router (equivale al TP2)
1. Crea la regla de NAT (*masquerade*) hacia `ether1`.
2. Protege la cadena `input` del router: acepta las conexiones establecidas y el ICMP, y descarta todo lo demás que entre por `ether1`.
3. **PRUEBA 3:** `lab-client` llega a Internet. Muestra el contador de la regla de NAT.
4. **PRUEBA 4:** Desde el host, demuestra que el DNS del router **no** responde por la WAN y que sí responde por la LAN.
   - *Pregunta conceptual:* ¿Qué pasaba con `allow-remote-requests=yes` antes de proteger la cadena `input`? ¿Por qué es un problema en un router real?
   - *Pregunta conceptual:* Si administrabas el router por SSH a su IP de `ether1`, ¿qué pasó al aplicar la última regla? ¿Cómo lo evitarías en un equipo remoto?

### Parte 3: VLANs y firewall entre VLANs (equivale al TP3)
1. Crea las interfaces `vlan10` y `vlan20` sobre `ether2` (router *on a stick*) y asígnales los gateways de la tabla.
2. En `lab-server`, crea `enp2s0.10` y `enp2s0.20`, muévelas a los namespaces `pc10` y `pc20` y configura sus direcciones y rutas.
3. Implementa una cadena `forward` restrictiva que:
   - acepte las conexiones ya establecidas;
   - permita que la VLAN 20 (docentes) inicie comunicaciones hacia la VLAN 10 (alumnos);
   - permita que las redes internas salgan a Internet;
   - descarte todo lo demás.
4. **PRUEBA 5:** `pc20 → pc10` funciona; `pc10 → pc20` no; `pc10` sale a Internet.
5. **PRUEBA 6:** Captura en `enp2s0` de `lab-server` (con `tcpdump -e`) un ping de `pc20` a `pc10` y señala con qué etiqueta pasa cada trama.
6. **PRUEBA 7:** Muestra los contadores de la cadena `forward` (`/ip firewall filter print stats`) y explica qué regla contó cada prueba.
   - *Pregunta conceptual:* Compara la regla final `action=drop` con el `policy drop` de nftables del TP3. ¿Qué pasaría si la pusieras primera?

### Parte 4: Hotspot para invitados (equivale al TP4)
1. Crea `vlan30` con `192.168.30.1/24`, agrégala a la lista `LAN` y configura DHCP para invitados (rango `.100–.199`, lease de 30 minutos).
2. Crea un Hotspot sobre `vlan30` con nombre DNS `portal.lab.local`, que acepte login por usuario y contraseña y también el modo *trial* (aceptar sin usuario). Crea el usuario `invitado1`.
3. En `lab-server`, crea `enp2s0.30`, muévela al namespace `invitado` y obtén IP por DHCP.
4. **PRUEBA 8:** Antes del login, `curl -i http://example.com` devuelve una redirección al portal; `curl https://example.com` falla; `ping 1.1.1.1` falla.
5. **PRUEBA 9:** Inicia sesión con `invitado1` y muestra `/ip hotspot active print`. Después, HTTP, HTTPS y ping funcionan, pero el invitado sigue sin llegar a `pc10`.
6. **PRUEBA 10:** Cierra la sesión desde el router e inicia una sesión *trial*. Muestra con qué nombre de usuario aparece.
7. **PRUEBA 11:** Captura en `lab-server` el login de la PRUEBA 9 y muestra en qué forma viaja la contraseña.
   - *Pregunta conceptual:* Lista las reglas NAT dinámicas que creó el Hotspot (`/ip firewall nat print where dynamic`). ¿Cuáles equivalen a las reglas que escribiste a mano en el TP4?
   - *Pregunta conceptual:* ¿Qué diferencia hay entre `http-pap` y `http-chap`? ¿Cuál dejarías habilitado y por qué?

## Capturas y Entregables
- Configuración del router: salida de `/export` (sin contraseñas).
- Resultados de las PRUEBAS 1 a 11.
- Captura de etiquetas de la PRUEBA 6 y del login de la PRUEBA 11, con lo importante señalado.
- Una tabla que relacione cada servicio de RouterOS con su equivalente en Linux en los TP1 a TP4.
- Respuestas a las preguntas conceptuales.

## Criterios de Evaluación
La actividad es optativa. Se considera completa si el MikroTik entrega IP y resuelve nombres en la LAN, hace NAT sin exponer sus servicios por la WAN, separa las VLANs con la política pedida, intercepta a los invitados hasta que inician sesión, y la tabla de equivalencias con Linux es correcta.

> Guía de desarrollo con comandos y resultados de referencia: `guia-estudiante/GUIA-COMPLEMENTARIA-MIKROTIK.md`.
