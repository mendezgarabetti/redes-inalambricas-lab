# TP6: AP Wi-Fi Completamente Virtual

## Objetivos Pedagógicos
- Simular radios 802.11 con el módulo del kernel `mac80211_hwsim`.
- Desplegar un Access Point por software con `hostapd` y conectar un cliente con `wpa_supplicant`.
- Usar *network namespaces* para que el cliente se comporte como otra computadora.
- Capturar y analizar tramas 802.11 reales: Beacon, Probe, Authentication, Association y el **4-way handshake** de WPA2.
- Comparar WPA2-Personal (PSK) con WPA3-Personal (SAE).

## Topología
Todo el TP se realiza en `LAB-SERVER`. Las radios de `mac80211_hwsim` sólo se “escuchan” entre sí dentro del mismo kernel, por eso el cliente es un namespace y no la VM `LAB-CLIENT`.

```text
            "aire" simulado  ←── captura en hwsim0 (radiotap)
  wlan0 (AP · hostapd)                 [ cliente ] wlan1 (wpa_supplicant)
  SSID WIFI-UNCUYO · canal 6
```

## Consignas

### Parte 1: Radios virtuales
1. Instala `hostapd`, `wpasupplicant`, `iw` y `tshark`.
2. Carga `mac80211_hwsim` con 3 radios. Identifica con `iw dev` qué `phy` corresponde a cada interfaz.
3. Levanta la interfaz de monitor `hwsim0`.
4. Crea el namespace `cliente` y mueve a él el `phy` de `wlan1`.
5. **PRUEBA 1:** Muestra `iw dev` en el sistema y dentro del namespace.
   - *Pregunta conceptual:* ¿Por qué se mueve el `phy` y no sólo la interfaz?

### Parte 2: WPA2-Personal
1. Configura `hostapd` en `wlan0` con el SSID `WIFI-UNCUYO`, canal 6, WPA2-PSK con CCMP.
2. Inicia una captura en `hwsim0` y levanta el AP.
3. Conecta el cliente con `wpa_supplicant` desde el namespace.
4. **PRUEBA 2:** Demuestra la conexión con `iw dev wlan1 link` y con el log de `wpa_supplicant` (`Key negotiation completed`, `CTRL-EVENT-CONNECTED`).
5. **PRUEBA 3:** Desde el AP, muestra la estación asociada (`iw dev wlan0 station dump`).

### Parte 3: Análisis de la captura
1. **PRUEBA 4:** Identifica en la captura, en orden: Beacon, Probe Request/Response, Authentication (2), Association Request/Response y los 4 mensajes EAPOL.
2. Para cada tipo de trama, indica su subtipo 802.11 y su función.
3. En un Beacon, localiza el SSID, el intervalo de beacon y el *RSN Information Element* (cifrado y gestión de claves anunciados).
   - *Pregunta conceptual:* En WPA2-PSK, las tramas “Authentication” no verifican la contraseña. ¿En qué momento se demuestra que el cliente la conoce?
   - *Pregunta conceptual:* ¿Qué obtiene un atacante que captura el 4-way handshake de una red con PSK débil?

### Parte 4: WPA3-Personal (SAE)
1. Reconfigura el AP y el cliente con `wpa_key_mgmt=SAE`, `sae_password` e `ieee80211w=2` (PMF obligatorio).
2. **PRUEBA 5:** Demuestra la conexión y compara la captura con la de la Parte 3: ¿cuántas tramas de autenticación hay ahora y qué contienen?
   - *Pregunta conceptual:* ¿Qué ataque de la Parte 3 mitiga SAE y por qué?

## Capturas y Entregables
- Configuraciones de hostapd y wpa_supplicant (WPA2 y WPA3).
- Resultados de las PRUEBAS 1 a 5.
- Capturas `.pcap` de ambas conexiones, con las tramas identificadas.
- Tabla de tramas (subtipo, origen, destino, función).
- Respuestas a las preguntas conceptuales.

## Criterios de Evaluación
El TP se considerará aprobado si el cliente se asocia al AP virtual con WPA2 y WPA3, y el estudiante identifica y explica en la captura la secuencia completa de conexión, el 4-way handshake y la diferencia entre PSK y SAE.

> Guía de desarrollo con comandos y resultados de referencia: `guia-estudiante/GUIA-ESTUDIANTE-TPs.md`, sección TP6.
