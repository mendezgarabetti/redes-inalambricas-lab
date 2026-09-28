# TP5: Wi-Fi Empresarial (802.1X, EAP y RADIUS)

## Objetivos Pedagógicos
- Diferenciar WPA2-Personal (PSK, una clave compartida) de WPA2-Enterprise (802.1X, credenciales por usuario).
- Identificar los roles de 802.1X: *Supplicant*, *Authenticator* y *Authentication Server*.
- Instalar y configurar FreeRADIUS con usuarios locales.
- Distinguir los dos tramos de la autenticación: **EAPOL** (cliente ↔ AP) y **RADIUS** (AP ↔ servidor).
- Analizar una autenticación **PEAP-MSCHAPv2** completa y el origen de las claves de cifrado (PMK).

## Requisito previo
La Parte 2 usa la radio virtual (`mac80211_hwsim`) y el namespace `cliente` del **TP6**. Se recomienda realizar el TP6 antes que la Parte 2 de este TP.

## Topología
Todo el TP se realiza en `LAB-SERVER`.

```text
 [ cliente ] wpa_supplicant (wlan1)  ── EAPOL ──  hostapd (wlan0)  ── RADIUS UDP 1812 ──  FreeRADIUS
  Supplicant                                     Authenticator      (127.0.0.1)          Authentication Server
```

| Usuario | Contraseña |
|---|---|
| `alumno1` | `alumno123` |
| `docente1` | `docente123` |

## Consignas

### Parte 1: Servidor RADIUS
1. Instala `freeradius` y `freeradius-utils`.
2. Da de alta los usuarios de la tabla en `/etc/freeradius/3.0/mods-config/files/authorize`, **al principio del archivo**.
3. Verifica la configuración (`freeradius -XC`) y reinicia el servicio.
4. **PRUEBA 1:** Con `radtest`, obtén un `Access-Accept` para `alumno1` con la contraseña correcta.
5. **PRUEBA 2:** Con `radtest`, obtén un `Access-Reject` con una contraseña incorrecta.
6. **PRUEBA 3:** Captura en la interfaz `lo` (puerto UDP 1812) el intercambio de la PRUEBA 1.
   - *Pregunta conceptual:* ¿Qué rol está simulando `radtest`? ¿Qué es el secreto compartido `testing123` y quién lo conoce?

### Parte 2: 802.1X con AP virtual
1. Configura `hostapd` sobre `wlan0` con el SSID `UNCUYO-EDU`, seguridad WPA2-Enterprise (`wpa_key_mgmt=WPA-EAP`, `ieee8021x=1`) y FreeRADIUS como servidor de autenticación.
2. Configura `wpa_supplicant` en el namespace `cliente` para conectarse con **PEAP-MSCHAPv2** como `alumno1`, **validando el certificado del servidor** (`ca_cert`).
3. Captura simultáneamente en `hwsim0` (aire) y en `lo` (RADIUS).
4. **PRUEBA 4:** Demuestra la conexión con `iw dev wlan1 link` y con los eventos `CTRL-EVENT-EAP-SUCCESS` y `CTRL-EVENT-CONNECTED` del log de `wpa_supplicant`.
5. **PRUEBA 5:** En el log de `hostapd`, muestra el método EAP con el que se autenticó el cliente y la finalización del 4-way handshake.
6. **PRUEBA 6:** En la captura RADIUS, cuenta los pares `Access-Request`/`Access-Challenge` e identifica el `Access-Accept` final y sus atributos `MS-MPPE-*`.
   - *Pregunta conceptual:* ¿Por qué PEAP necesita muchas rondas y `radtest` sólo una?
   - *Pregunta conceptual:* ¿Para qué recibe el AP las claves `MS-MPPE-*`?
7. **PRUEBA 7:** Intenta conectar con una contraseña incorrecta y documenta qué registran el supplicant, hostapd y FreeRADIUS (`freeradius -X`).

## Capturas y Entregables
- Entradas de usuarios en `authorize` y configuraciones de hostapd y wpa_supplicant.
- Resultados de las PRUEBAS 1, 2, 4, 5 y 7.
- Capturas `.pcap` del aire y de RADIUS, con los paquetes relevantes señalados.
- Respuestas a las preguntas conceptuales.
- Comparación WPA2-PSK vs. WPA2-Enterprise: qué cambia para el usuario, para el AP y para la seguridad.
- Análisis: ¿qué riesgo corre un cliente configurado **sin** validar el certificado del servidor?

## Criterios de Evaluación
El TP se considerará aprobado si FreeRADIUS acepta y rechaza credenciales correctamente, el cliente se autentica con PEAP-MSCHAPv2 contra el AP virtual y el estudiante identifica correctamente los tramos EAPOL y RADIUS, el túnel PEAP y el origen de las claves de cifrado.

> Guía de desarrollo con comandos y resultados de referencia: `guia-estudiante/GUIA-ESTUDIANTE-TPs.md`, sección TP5.
