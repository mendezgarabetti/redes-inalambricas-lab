# Redes Inalámbricas · Laboratorio con máquinas virtuales

Material de cátedra de **Redes Inalámbricas** (ITU · Universidad Nacional de Cuyo): teoría previa a los laboratorios y guía del estudiante para los TP1 a TP7, sobre VMs Debian 12 con KVM/libvirt y radio Wi-Fi virtual (`mac80211_hwsim`).

## Contenido

### `teoria/` · Presentaciones previas a TP1 y TP2 (PDF)

| Presentación | Cuándo | Archivo |
|---|---|---|
| 01 · DHCP | antes del TP1 | `PDF/01-FUNDAMENTOS-DHCP.pdf` |
| 02 · DNS | antes del TP1 | `PDF/02-FUNDAMENTOS-DNS.pdf` |
| 03 · Routing y gateway | antes del TP2 | `PDF/03-ROUTING-GATEWAY.pdf` |
| 04 · NAT y troubleshooting | antes del TP2 | `PDF/04-NAT-TROUBLESHOOTING.pdf` |
| 05 · Integración TP1 + TP2 | después del TP2 | `PDF/05-INTEGRACION-TP1-TP2.pdf` |

También: `PREGUNTAS-REPASO.md` (30 preguntas) y `GLOSARIO.md`.

### `guia-estudiante/` · Desarrollo de los TP1 a TP7

- `GUIA-ESTUDIANTE-TPs.md`: TP1–TP2 (DHCP, DNS, routing, NAT) como repaso operativo y, en profundidad, TP3 VLAN/trunk/firewall, TP4 portal cautivo, TP5 802.1X/EAP/RADIUS, TP6 Wi-Fi virtual (WPA2/WPA3) y TP7 integrador con VLAN dinámica por RADIUS.
- `configs/`: configuraciones validadas (hostapd, wpa_supplicant, FreeRADIUS, dnsmasq, nftables, portal).
- `capturas-referencia/`: capturas `.pcap` reales de la validación.

### `laboratorio/` · Enunciados y entorno

- `enunciados/`: los siete TP completos (TP1 DHCP/DNS · TP2 routing/NAT · TP3 VLAN/firewall · TP4 portal cautivo · TP5 802.1X/RADIUS · TP6 Wi-Fi virtual · TP7 integrador).
- `entorno/`: script de creación de VMs, redes libvirt y scripts de verificación. Instrucciones en `laboratorio/README.md`.

Las contraseñas y secretos que aparecen en las configuraciones y scripts son **sólo de laboratorio**. Las imágenes de disco, los discos de las VMs y la clave SSH no se incluyen.

Autor: Mgter. Ing. Miguel Méndez Garabetti.
