# TP4: Wi-Fi para Invitados con Portal Cautivo

## Objetivos Pedagógicos
- Comprender cómo funciona un portal cautivo en una red Wi-Fi pública (aeropuertos, shoppings, universidades).
- Implementar la redirección de tráfico HTTP con DNAT en nftables.
- Implementar la “autorización” de un cliente como el alta de su dirección en un **set** de nftables con vencimiento.
- Comprender por qué el tráfico HTTPS no puede redirigirse de forma transparente.
- Analizar el estado del cliente antes y después de aceptar los términos de uso.

## Topología
Todo el TP se realiza en `LAB-SERVER`, que actúa como gateway de la red de invitados y tiene salida a Internet por `enp1s0`. El invitado es un *network namespace* conectado por un par `veth` al bridge `brvlan30`. En el TP7 ese bridge será el del SSID de invitados.

```text
 [ invitado ] eth0 (DHCP: 192.168.30.1xx)
      │ veth
 [ brvlan30 ] 192.168.30.1/24  ── LAB-SERVER: dnsmasq · nftables · portal (:8080)
                                        │
                                     enp1s0 ── Internet
```

## Consignas

### Parte 1: Red de invitados
1. Crea el bridge `brvlan30` con la IP `192.168.30.1/24`.
2. Crea el namespace `invitado` y conéctalo al bridge.
3. Configura `dnsmasq` (con `bind-interfaces`) para entregar en `brvlan30` el rango `192.168.30.100–199` con lease de 30 minutos, gateway y DNS `192.168.30.1`, y reenvío de consultas a un DNS público.
4. **PRUEBA 1:** El invitado obtiene IP por DHCP y resuelve `example.com`.

### Parte 2: Firewall del portal
1. Habilita el forwarding y el NAT (masquerade) hacia `enp1s0`.
2. Crea en nftables un set `autorizados` de direcciones IPv4 con vencimiento de 1 hora.
3. Crea una cadena de NAT en `prerouting` que redirija al puerto `8080` de `192.168.30.1` todo el tráfico TCP al puerto 80 que venga de `brvlan30` y **no** esté en el set.
4. Crea una cadena `forward` con política `drop` que sólo deje salir hacia Internet a los invitados que estén en el set.

### Parte 3: Servidor del portal
1. Despliega un servidor web en `192.168.30.1:8080` que muestre una página de términos de uso con un enlace “Acepto”.
2. Al aceptar, el servidor debe agregar la IP del cliente al set `autorizados`. Puedes usar el portal didáctico `guia-estudiante/configs/portal.py` o implementar el tuyo.

### Parte 4: Pruebas (desde el namespace `invitado`)
1. **PRUEBA 2:** `curl http://example.com` devuelve la página del portal.
2. **PRUEBA 3:** `curl https://example.com` **no** muestra el portal.
   - *Pregunta conceptual:* ¿Por qué no se puede redirigir HTTPS al portal? ¿Qué vería el navegador si se hiciera?
3. **PRUEBA 4:** `ping 1.1.1.1` está bloqueado antes de aceptar.
4. **PRUEBA 5:** Acepta los términos. Muestra el contenido del set con el tiempo restante.
5. **PRUEBA 6:** `curl http://example.com` devuelve el sitio real y `curl https://example.com` responde `200`.
6. **PRUEBA 7:** Captura en `brvlan30` la petición HTTP de la PRUEBA 2 y la respuesta del portal.
   - *Pregunta conceptual:* ¿Qué IP de destino tiene el paquete que envía el invitado? ¿Y el que recibe el portal? ¿En qué cadena se hizo el cambio?

## Capturas y Entregables
- Configuración de dnsmasq para la red de invitados.
- Ruleset de nftables completo, con el set y su contenido antes y después de aceptar.
- Código o configuración del portal.
- Resultados de las PRUEBAS 1 a 6 y captura de la PRUEBA 7.
- Respuestas a las preguntas conceptuales.
- Breve análisis de seguridad: ¿qué pasa si otro equipo falsifica la IP (o la MAC) de un invitado autorizado?

## Criterios de Evaluación
El TP se considerará aprobado si el invitado obtiene configuración por DHCP, es redirigido al portal por HTTP mientras no está autorizado, no tiene salida a Internet hasta aceptar, y después de aceptar navega normalmente. Además, debe explicar por qué HTTPS no se redirige.

> Guía de desarrollo con comandos y resultados de referencia: `guia-estudiante/GUIA-ESTUDIANTE-TPs.md`, sección TP4.
