#!/bin/bash
# ricos install - rough TTY installer, default English
# choose French during setup if you prefer
# WARNING: wipes target disk completely

set -e

[[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }

INSTALL_LANG="en"

# helper: $1 = English, $2 = French
say() { if [[ "$INSTALL_LANG" == "fr" ]]; then echo "$2"; else echo "$1"; fi; }

# helper: $1 = prompt EN, $2 = prompt FR
ask() { if [[ "$INSTALL_LANG" == "fr" ]]; then read -p "$2 " REPLY; else read -p "$1 " REPLY; fi; }

# ============================================================
# 1. Langue de l'installeur / Installer language
# ============================================================
clear
say "========================================" "========================================"
say "  RicOS Installer (TTY, no GUI)" "  Installeur RicOS (TTY, pas de GUI)"
say "========================================"
echo ""
say "Choose language / Choisir la langue :"
echo "  1) English (default)"
echo "  2) Français"
ask "choice [1-2]:" "choix [1-2]:"
case "$REPLY" in
   2) INSTALL_LANG="fr" ;;
   *) INSTALL_LANG="en" ;;
esac

# ============================================================
# 2. Langue système / System locale
# ============================================================
say ""
say "System language / Langue système :"
echo "  1) en_US (English)"
echo "  2) fr_FR (Français)"
echo "  3) de_DE (Allemand)"
ask "choice [1-3]:" "choix [1-3]:"
case "$REPLY" in
   2) LOCALE="fr_FR.UTF-8" ;;
   3) LOCALE="de_DE.UTF-8" ;;
   *) LOCALE="en_US.UTF-8" ;;
esac

# ============================================================
# 3. Clavier / Keyboard layout
# ============================================================
say ""
say "Keyboard layout / Disposition clavier :"
echo "  1) us (QWERTY)"
echo "  2) fr (AZERTY)"
echo "  3) fr-bepo (BÉPO)"
ask "choice [1-3]:" "choix [1-3]:"
case "$REPLY" in
   2) KEYMAP="fr" ;;
   3) KEYMAP="fr-bepo" ;;
   *) KEYMAP="us" ;;
esac
loadkeys "$KEYMAP" 2>/dev/null || true

# ============================================================
# 4. Fuseau horaire / Timezone
# ============================================================
say ""
say "Timezone / Fuseau horaire :"
echo "  1) UTC"
echo "  2) Europe/Paris"
echo "  3) Europe/Brussels"
echo "  4) other / autre"
ask "choice [1-4]:" "choix [1-4]:"
case "$REPLY" in
   2) TIMEZONE="Europe/Paris" ;;
   3) TIMEZONE="Europe/Brussels" ;;
   4) ask "timezone (ex: Europe/Lyon):" "fuseau (ex: Europe/Lyon):"; TIMEZONE="$REPLY" ;;
   *) TIMEZONE="UTC" ;;
esac

# ============================================================
# 5. Disque cible / Target disk
# ============================================================
say ""
say "Available disks / Disques disponibles :"
lsblk -d -n -o NAME,SIZE | grep -v loop
echo ""
ask "Target disk (ex: /dev/sda /dev/nvme0n1):" "Disque cible (ex: /dev/sda /dev/nvme0n1):"
DISK="$REPLY"

if [[ "$DISK" == *nvme* ]] || [[ "$DISK" == *mmcblk* ]]; then
   EFI_PART="${DISK}p1"
   ROOT_PART="${DISK}p2"
else
   EFI_PART="${DISK}1"
   ROOT_PART="${DISK}2"
fi

say ""
say "!!! WARNING !!!" "!!! ATTENTION !!!"
say "The disk $DISK will be COMPLETELY wiped." "Le disque $DISK va être TOTALLEMENT effacé."
say "EFI: $EFI_PART  ROOT: $ROOT_PART"
ask "Type YES to continue / Taper OUI pour continuer:" "Taper OUI pour continuer:"
if [[ "$REPLY" != "YES" && "$REPLY" != "OUI" ]]; then
   say "Cancelled." "Annulé."
   exit 1
fi

# ============================================================
# 6. Partitionnement / Partitioning
# ============================================================
say ""
say "Partitioning..." "Partitionnement..."
parted "$DISK" --script mklabel gpt
parted "$DISK" --script mkpart ESP fat32 1MiB 513MiB
parted "$DISK" --script set 1 esp on
parted "$DISK" --script mkpart primary ext4 513MiB 100%
sleep 2
partprobe "$DISK" || true

say "Formatting..." "Formatage..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 -F "$ROOT_PART"

# ============================================================
# 7. Montage / Mounting
# ============================================================
say "Mounting..." "Montage..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# ============================================================
# 8. Config NixOS
# ============================================================
say "Generating NixOS config..." "Génération config NixOS..."
nixos-generate-config --root /mnt
CONF=/mnt/etc/nixos/configuration.nix
sed -i '$ { /^}$/d; }' "$CONF"

ROOT_PASS="ricoroot"
if command -v openssl >/dev/null 2>&1; then
   ROOT_HASH=$(openssl passwd -6 "$ROOT_PASS" 2>/dev/null || echo "$ROOT_PASS")
else
   ROOT_HASH="$ROOT_PASS"
fi

cat >> "$CONF" << EOF

  # ricOS custom stuff
  networking.hostName = "ricos";
  i18n.defaultLocale = "$LOCALE";
  i18n.supportedLocales = [ "$LOCALE/UTF-8" ];
  console.keyMap = "$KEYMAP";
  console.font = "Lat2-Terminus16";
  time.timeZone = "$TIMEZONE";
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "$DISK";
  boot.loader.grub.efiSupport = true;
  environment.systemPackages = with pkgs; [ vim git curl wget fastfetch ];
  users.users.root.password = "$ROOT_HASH";
  system.stateVersion = "24.11";
}
EOF

# ============================================================
# 9. Installation
# ============================================================
say ""
say "Running nixos-install (grab a coffee)..." "Lancement nixos-install (prends un café)..."
nixos-install --root /mnt --no-root-passwd

# ============================================================
# 10. Fin / Done
# ============================================================
say ""
say "========================================" "========================================"
say "  INSTALLATION FINISHED (normally)" "  INSTALLATION TERMINÉE (normalement)"
say "========================================" "========================================"
say "Temporary root password: $ROOT_PASS" "Mot de passe root temporaire : $ROOT_PASS"
say "Change it after first boot: passwd" "Change-le après premier boot : passwd"
say "Reboot and remove the ISO." "Redémarre et retire l'ISO."
echo ""
ask "Reboot now? (y/n):" "Redémarrer maintenant ? (o/n):"
if [[ "$REPLY" == "y" || "$REPLY" == "o" ]]; then
   reboot
fi
