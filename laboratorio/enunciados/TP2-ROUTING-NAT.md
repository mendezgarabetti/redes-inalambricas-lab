# TP2: Gateway, Routing y NAT

## Objetivos Pedagógicos
- Comprender la función de un router y el uso de múltiples interfaces de red.
- Configurar un Default Gateway y verificar la tabla de enrutamiento (routing).
- Habilitar el reenvío de paquetes (IPv4 Forwarding) en Linux.
- Comprender e implementar Traducción de Direcciones de Red (NAT - Masquerading) para dar acceso a Internet a redes privadas.
- Utilizar herramientas de diagnóstico como `ping` y `traceroute`.

## Topología
Trabajarás con dos máquinas virtuales: `LAB-ROUTER` (conectado a Internet y a la LAN) y `LAB-CLIENT` (conectado sólo a la LAN).

```text
[ Internet ]
      | 
[ LAB-ROUTER ] (IP Dinámica en WAN)
      | 
   (LAN: 10.20.20.1/24)
      |
[ LAB-CLIENT ] (IP Estática o DHCP: 10.20.20.100/24)
```

## Consignas

### Parte 1: Configuración del Router
1. `LAB-ROUTER` tiene dos interfaces. Configura la interfaz WAN por DHCP y la interfaz LAN de forma estática con `10.20.20.1/24`.
2. Habilita el IPv4 forwarding en el kernel de forma persistente (por ejemplo, en `/etc/sysctl.d/99-router.conf`). Comprueba que `sysctl net.ipv4.ip_forward` devuelve `1`.
3. Instala `nftables` y configura reglas para hacer NAT (Masquerading) del tráfico que provenga de `10.20.20.0/24` y salga por la interfaz WAN.

### Parte 2: Configuración del Cliente y Pruebas Obligatorias
0. **Condición previa:** el cliente debe salir a otras redes **sólo** a través del router: `ip route` debe mostrar una única ruta por defecto, `via 10.20.20.1`.
1. **Conexión Local (PRUEBA 1 y 2):** En `LAB-CLIENT`, configura la IP `10.20.20.100`, con Gateway `10.20.20.1` y un DNS público (ej. `8.8.8.8`). Muestra la tabla de enrutamiento (`ip route`) e identifica la ruta por defecto. Demuestra que `ping 10.20.20.1` funciona.
2. **Conexión a Internet (PRUEBA 3, 4 y 6):** 
   - Desde el Router, haz ping a `8.8.8.8` para asegurar que el router tiene salida.
   - Desde el Cliente, haz ping a `1.1.1.1` o `8.8.8.8` y utiliza `curl https://example.com`. 
3. **Traza de Rutas (PRUEBA 5):**
   Ejecuta `traceroute 1.1.1.1` (o a otro destino público).
   - *Pregunta Conceptual:* Explica por qué el primer salto es `10.20.20.1`.
4. **Verificación de NAT (PRUEBA 7 y 8):**
   - Muestra las reglas cargadas (`nft list ruleset`).
   - Ejecuta `tcpdump` simultáneamente en ambas interfaces del router (`tcpdump -i LAN_IF icmp` y `tcpdump -i WAN_IF icmp`). Realiza un ping desde el cliente a Internet.
   - *Pregunta Conceptual:* Explica qué transformación ocurrió en las IPs observando los paquetes en ambas capturas.

### Parte 3: Troubleshooting y Pruebas Avanzadas (PRUEBA 9 y 10)
1. **Deshabilitar Forwarding:** Ejecuta `sysctl -w net.ipv4.ip_forward=0` en el router. Intenta navegar desde el cliente. Restáuralo a `1`.
2. **Eliminar NAT:** Elimina temporalmente la regla de masquerading.
   - *Pregunta Conceptual:* ¿Por qué los pings hacia Internet dejan de funcionar, aunque el router los esté enviando? (PISTA: ¿A dónde intenta responder el servidor de destino?). Restaura la configuración al terminar.

## Capturas y Entregables
- Archivos de configuración del router (interfaces, sysctl, reglas nftables).
- Salida de `ip route` del cliente.
- Capturas o recortes demostrando el funcionamiento de NAT (tcpdump a dos bandas).
- Respuestas a las preguntas conceptuales de las PRUEBAS 5, 8 y 10.

## Criterios de Evaluación
El TP se considerará validado si logras dar acceso a Internet a la LAN privada configurando correctamente el reenvío de paquetes y el NAT, demostrando entender la traducción de direcciones.
