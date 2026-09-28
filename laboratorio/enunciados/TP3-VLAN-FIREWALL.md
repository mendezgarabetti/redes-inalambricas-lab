# TP3: Segmentación con VLANs 802.1Q, trunk y firewall entre VLANs

## Objetivos Pedagógicos
- Comprender por qué una red de campus separa a sus usuarios (docentes, estudiantes, invitados) en VLANs distintas y cómo se relaciona esto con los SSID de una red Wi-Fi.
- Distinguir puerto de **acceso** (una VLAN, sin etiqueta) y puerto **trunk** (varias VLANs, con etiqueta 802.1Q).
- Configurar un switch Linux con filtrado de VLAN (`bridge vlan_filtering`).
- Implementar un router *on a stick* con subinterfaces VLAN.
- Demostrar que dos VLANs están aisladas en capa 2 y que la comunicación entre ellas depende del router.
- Aplicar una política de firewall por defecto restrictiva (`policy drop`) entre VLANs con nftables.

## Topología
Todo el TP se realiza dentro de `LAB-SERVER`. Cada “equipo” es un *network namespace* y cada “cable” un par `veth`.

```text
   pc10 (VLAN 10)            pc20 (VLAN 20)
   192.168.10.10/24          192.168.20.10/24
        │ p10 (acceso)            │ p20 (acceso)
        └──────────┬──────────────┘
              [ sw ]  bridge con vlan_filtering
                   │ ptrunk (trunk: VLAN 10 y 20)
               [ router ]  eth0.10 = 192.168.10.1/24
                           eth0.20 = 192.168.20.1/24
```

| VLAN | Uso | Red | Gateway |
|---|---|---|---|
| 10 | Alumnos | 192.168.10.0/24 | 192.168.10.1 |
| 20 | Docentes | 192.168.20.0/24 | 192.168.20.1 |

## Consignas

### Parte 1: Switch con VLANs
1. Crea los namespaces `pc10`, `pc20` y `router`.
2. Crea un bridge `sw` con filtrado de VLAN habilitado.
3. Conecta cada namespace al switch con un par `veth`. Quita la VLAN 1 por defecto de todos los puertos.
4. Configura `p10` como puerto de **acceso** de la VLAN 10 y `p20` como puerto de acceso de la VLAN 20 (PVID, sin etiqueta).
5. Configura `ptrunk` como **trunk** que transporte las VLANs 10 y 20 etiquetadas.
6. **PRUEBA 1:** Muestra la tabla de VLANs del switch (`bridge vlan show`) y explica cada línea.

### Parte 2: Equipos y router *on a stick*
1. Asigna a `pc10` y `pc20` sus direcciones y su ruta por defecto hacia el gateway de su VLAN.
2. En el namespace `router`, crea las subinterfaces `eth0.10` y `eth0.20` sobre `eth0` y asígnales los gateways.
3. **PRUEBA 2:** Con `net.ipv4.ip_forward=0` en el router, demuestra que `pc10` alcanza a su gateway pero **no** a `pc20`.
4. **PRUEBA 3:** Habilita el forwarding en el router y demuestra que `pc10` y `pc20` se comunican en ambos sentidos.
   - *Pregunta conceptual:* ¿Por qué falla la PRUEBA 2 si el router tiene una IP en cada VLAN?

### Parte 3: Observación de las etiquetas
1. **PRUEBA 4:** Captura **simultáneamente** en `ptrunk` y en `p10` (con `tcpdump -e`) mientras `pc20` hace ping a `pc10`.
   - *Pregunta conceptual:* ¿Cuántas veces pasa el mismo paquete por el trunk y con qué etiqueta cada vez? ¿Por qué la trama del puerto de acceso es 4 bytes más corta?
2. **PRUEBA 5:** Asigna temporalmente a `pc20` una dirección de la red 192.168.10.0/24 sin cambiarlo de VLAN. Demuestra que no se comunica con `pc10`.
   - *Pregunta conceptual:* ¿Qué demuestra esta prueba sobre la relación entre subred IP y VLAN?

### Parte 4: Firewall entre VLANs
1. En el router, carga una tabla nftables con una cadena `forward` de política `drop` que:
   - permita el tráfico de conexiones ya establecidas;
   - permita que la VLAN 20 (docentes) inicie comunicaciones hacia la VLAN 10 (alumnos);
   - descarte todo lo demás.
2. **PRUEBA 6:** Demuestra que `pc20 → pc10` funciona y que `pc10 → pc20` no.
   - *Pregunta conceptual:* ¿Por qué `pc10` puede **responder** a `pc20` si no puede **iniciar** una comunicación hacia él?

## Capturas y Entregables
- Comandos utilizados para crear el switch, los puertos y el router.
- Salida de `bridge vlan show` comentada.
- Capturas de trunk y acceso (PRUEBA 4) con las etiquetas señaladas.
- Resultados de las PRUEBAS 2, 3, 5 y 6.
- Ruleset de nftables aplicado.
- Respuestas a las preguntas conceptuales.
- Diagrama de la topología implementada.

## Criterios de Evaluación
El TP se considerará aprobado si el switch separa correctamente las VLANs, el router permite el tránsito sólo cuando el forwarding está habilitado, las capturas muestran las etiquetas 802.1Q en el trunk y su ausencia en el puerto de acceso, y el firewall implementa la política pedida demostrándolo con pruebas en ambos sentidos.

> Guía de desarrollo con comandos y resultados de referencia: `guia-estudiante/GUIA-ESTUDIANTE-TPs.md`, sección TP3.
