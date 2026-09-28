# TP1: DHCP y DNS en una Red Local Simulada

## Objetivos Pedagógicos
- Comprender la configuración IP automática y el funcionamiento de DHCP.
- Identificar y capturar el proceso DORA (Discover, Offer, Request, ACK).
- Entender el concepto de 'lease' (concesión) y la configuración del gateway.
- Configurar y consultar un servicio DNS para resolución de nombres internos.
- Diferenciar entre conectividad IP básica (Ping por IP) y resolución de nombres.
- Realizar diagnósticos básicos de problemas de red.

## Topología
Trabajarás con dos máquinas virtuales conectadas a una red aislada llamada `LAB1` (subred `10.10.10.0/24`).

```text
[ LAB-CLIENT ] ---- (Red lab1: 10.10.10.0/24) ---- [ LAB-SERVER ]
 Cliente DHCP                                      IP: 10.10.10.10
```

## Consignas

### Parte 1: Configuración del Servidor
1. Ingresa a `LAB-SERVER`. Configura su interfaz de red con la IP estática `10.10.10.10/24`.
2. Instala el paquete `dnsmasq`.
3. Configura `dnsmasq` para que entregue IPs en el rango `10.10.10.100` a `10.10.10.200`.
4. El DHCP debe entregar como Gateway a `10.10.10.1` y como DNS a `10.10.10.10`.
5. Configura en dnsmasq un dominio interno llamado `lab.local` y los siguientes registros estáticos:
   - `server.lab.local` -> `10.10.10.10`
   - `router.lab.local` -> `10.10.10.1`

### Parte 2: Pruebas del Cliente (Pruebas Obligatorias)
1. **Verificar obtención de IP (PRUEBA 1 y 2):** 
   Enciende `LAB-CLIENT`, configúralo para obtener IP por DHCP (si no lo hace por defecto). Muestra la IP obtenida, la máscara, el gateway y los servidores DNS utilizando los comandos `ip addr`, `ip route` y `resolvectl status` (en estas VMs `/etc/resolv.conf` apunta al stub local `127.0.0.53`).
2. **Renovar el lease (PRUEBA 3):**
   Fuerza al cliente a liberar y renovar la concesión DHCP (en las VMs del laboratorio, que usan systemd-networkd: `networkctl renew <interfaz>` para renovar y `networkctl reconfigure <interfaz>` para liberar y obtener una concesión nueva con DORA completo).
3. **Capturar intercambio DHCP (PRUEBA 4):**
   Utilizando `tcpdump` o `Wireshark` en cualquiera de los extremos, captura los 4 paquetes del proceso DORA. (Filtro sugerido: `bootp` o `udp port 67 and port 68`). Guarda la captura o la salida.
4. **Resolución de Nombres (PRUEBA 5 y 6):**
   Utiliza `dig` o `nslookup` para resolver `server.lab.local`. Captura esta consulta DNS con tcpdump/Wireshark (filtro: `port 53`).

### Parte 3: Fallos Conceptuales (PRUEBA 7 y 8)
1. Detén el servicio `dnsmasq` en el servidor (`systemctl stop dnsmasq`).
2. Demuestra que aún puedes hacer `ping 10.10.10.10` pero NO puedes hacer `ping server.lab.local`.
   - *Pregunta conceptual:* ¿Por qué la comunicación por IP sigue funcionando si el servidor está caído?
3. Restaura el servicio y verifica que todo vuelva a funcionar.

## Capturas y Entregables
- Salidas de los comandos que demuestren la correcta configuración del servidor.
- Salidas en el cliente demostrando la correcta asignación (IP, GW, DNS).
- Archivos `.pcap` o recortes de texto de las capturas del proceso DHCP y las consultas DNS.
- Respuestas a las preguntas conceptuales.

## Criterios de Evaluación
El TP se considerará aprobado si lograste configurar un servidor DHCP funcional y capturar el proceso completo, demostrando comprender la diferencia entre conexión IP y resolución DNS.
