# TP7: Trabajo Práctico Integrador · Infraestructura Wi-Fi de Campus

## Consigna
La Universidad tiene tres tipos de usuarios: **docentes**, **estudiantes** e **invitados**. Diseña, implementa y documenta una infraestructura inalámbrica que ofrezca autenticación, direccionamiento, DNS, segmentación y acceso controlado a Internet, integrando lo trabajado en los TP1 a TP6.

## Objetivos Pedagógicos
- Integrar DHCP, DNS, routing, NAT, VLANs, firewall, portal cautivo, 802.1X y Wi-Fi virtual en una sola arquitectura.
- Asignar la VLAN de cada usuario **dinámicamente desde RADIUS** según sus credenciales.
- Emitir varios SSIDs desde una misma radio.
- Diseñar una política de firewall por roles y demostrarla con evidencia.

## Requisitos funcionales
1. **Dos SSIDs** en la misma radio virtual:
   - `UNCUYO-EDU`: WPA2-Enterprise (802.1X, PEAP-MSCHAPv2) contra FreeRADIUS.
   - `UNCUYO-INVITADOS`: abierto, con portal cautivo.
2. **VLAN dinámica:** FreeRADIUS asigna la VLAN según el usuario, con los atributos `Tunnel-Type`, `Tunnel-Medium-Type` y `Tunnel-Private-Group-Id`. Un usuario sin VLAN asignada **no** debe poder conectarse.
3. **Direccionamiento:**

   | Red | VLAN | Red IP | Gateway / DNS | Lease |
   |---|---|---|---|---|
   | Alumnos | 10 | 192.168.10.0/24 | 192.168.10.1 | 1 h |
   | Docentes | 20 | 192.168.20.0/24 | 192.168.20.1 | 1 h |
   | Invitados | 30 | 192.168.30.0/24 | 192.168.30.1 | 30 min |

4. **DNS** interno con dominio `campus.lab` y reenvío a un DNS público.
5. **Política de acceso:**
   - Alumnos → Internet: permitido.
   - Docentes → Internet y → red de alumnos: permitido.
   - Alumnos → red de docentes: **denegado y registrado** en el log.
   - Invitados → sólo portal hasta aceptar; luego, Internet por 1 hora.
   - Todo lo demás: denegado (política `drop`).
6. **Salida a Internet** con NAT por `enp1s0`.

## Topología
Todo se implementa en `LAB-SERVER`. Los clientes inalámbricos son namespaces con una radio de `mac80211_hwsim` cada uno (al menos: un alumno, un docente y un invitado).

```text
 UNCUYO-EDU (802.1X) ──► RADIUS decide VLAN ──► wlan0.10 ─ brvlan10 (alumnos)
                                            └─► wlan0.20 ─ brvlan20 (docentes)
 UNCUYO-INVITADOS (abierto) ─► wlan0_1 ──────────────────── brvlan30 (invitados)
                                                    │
                   dnsmasq · nftables (firewall + portal + NAT) · FreeRADIUS
                                                    │
                                                 enp1s0 ── Internet
```

## Consignas y pruebas obligatorias
1. **PRUEBA 1:** `radtest` para `alumno1` y `docente1` muestra los atributos de VLAN en el `Access-Accept`.
2. **PRUEBA 2:** Con PEAP, el log de `hostapd` muestra `VLAN ID 10` para el alumno y `VLAN ID 20` para el docente.
   - *Pregunta conceptual:* ¿Por qué los atributos que aparecen con `radtest` pueden **no** llegar al AP cuando el cliente usa PEAP? ¿Cómo lo resolviste?
3. **PRUEBA 3:** Cada cliente recibe por DHCP una IP de la red de su VLAN, con el gateway y el DNS correspondientes.
4. **PRUEBA 4:** `iw dev` muestra los dos SSIDs; `bridge link` muestra qué interfaz pertenece a cada bridge.
5. **PRUEBA 5:** Matriz de conectividad completa (tabla origen × destino) con el resultado de cada caso de la política de acceso.
6. **PRUEBA 6:** El intento alumno → docente aparece en el log del kernel con el prefijo del firewall.
7. **PRUEBA 7:** Invitado antes de aceptar: HTTP → portal, HTTPS → sin acceso, ping → bloqueado. Después de aceptar: navegación normal.
8. **PRUEBA 8:** Un usuario válido **sin** VLAN asignada en RADIUS es rechazado por el AP.

## Capturas y Entregables
1. Diagrama de la arquitectura (VLANs, bridges, IPs, SSIDs y servicios).
2. Todas las configuraciones: hostapd (incluido el archivo de VLANs), FreeRADIUS (usuarios y cambios en los sitios virtuales), dnsmasq, nftables y portal.
3. Evidencia de cada PRUEBA.
4. Capturas `.pcap`: RADIUS con atributos de VLAN, aire con los EAPOL de ambos usuarios y DHCP en al menos dos VLANs.
5. **Análisis de seguridad:** qué protege cada capa (802.1X, cifrado, VLAN, firewall, portal) y qué **no** protege.
6. Problemas encontrados y cómo se diagnosticaron.

## Criterios de Evaluación
| Criterio | Peso |
|---|---|
| Autenticación 802.1X funcional con VLAN dinámica por usuario | 25 % |
| Direccionamiento y DNS por VLAN | 15 % |
| Política de firewall implementada y demostrada (matriz completa) | 20 % |
| Portal cautivo funcional para invitados | 15 % |
| Calidad de las evidencias y capturas | 10 % |
| Análisis de seguridad y de problemas | 15 % |

El TP se considerará aprobado si se cumplen los requisitos 1 a 6 con evidencia verificable y el análisis de seguridad es correcto.

> Guía de desarrollo con comandos y resultados de referencia: `guia-estudiante/GUIA-ESTUDIANTE-TPs.md`, sección TP7.
