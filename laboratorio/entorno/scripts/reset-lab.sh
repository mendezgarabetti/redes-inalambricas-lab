#!/bin/bash
echo "--- Destruyendo laboratorio ---"
virsh destroy lab-server 2>/dev/null
virsh undefine lab-server --remove-all-storage 2>/dev/null

virsh destroy lab-client 2>/dev/null
virsh undefine lab-client --remove-all-storage 2>/dev/null

virsh destroy lab-router 2>/dev/null
virsh undefine lab-router --remove-all-storage 2>/dev/null

virsh destroy lab-mikrotik 2>/dev/null
virsh undefine lab-mikrotik --remove-all-storage 2>/dev/null

echo "Limpieza completada."
