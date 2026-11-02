#!/bin/bash
# ricos install - fait à la va-vite, pas de gui, tout en tty
# WARNING: efface le disque. you've been warned.

set -e

if [[ $EUID -ne 0 ]]; then
   echo "fais sudo pauvre hère"
   exit 1
fi

echo ""
echo "========================================"
echo "  RicOS installateur (ttymode, no gui)"
echo "========================================"
echo ""

# langue
echo "Langue ?"
echo "  1) fr_FR (français)"
echo "  2) en_US (anglais)"
echo "  3) de_DE (allemand)"
read -p "choix [1-3]: " LC_CHOICE
case $LC_CHOICE in
  1) LOCALE="fr_FR.UTF-8" ;;
  2) LOCALE="en_US.UTF-8" ;;
  3) LOCALE="de_DE.UTF-8" ;;
  *) LOCALE="fr_FR.UTF-8" ;;
esac

# clavier
echo ""
echo "Clavier ?"
echo "  1) fr (azerty)"
echo "  2) us (qwerty)"
echo "  3) bepo"
read -p "choix [1-3]: " KB_CHOICE
case $KB_CHOICE in
  1) KEYMAP="fr" ;;
  2) KEYMAP="us" ;;
  3) KEYMAP="fr-bepo" ;;
  *) KEYMAP="fr" ;;
esac
loadkeys $KEYMAP 2>/dev/null || true

# fuseau
echo ""
echo "Fuseau horaire ?"
echo "  1) Europe/Paris"
echo "  2) Europe/Brussels"
echo "  3) UTC"
echo "  4) autre"
read -p "choix [1-4]: " TZ_CHOICE
case $TZ_CHOICE in
  1) TIMEZONE="Europe/Paris" ;;
  2) TIMEZONE="Europe/Brussels" ;;
  3) TIMEZONE="UTC" ;;
  4) read -p "fuseau (ex: Europe/Lyon): " TIMEZONE ;;
  *) TIMEZONE="Europe/Paris" ;;
esac

# disque
echo ""
echo "Disques disponibles :"
lsblk -d -n -o NAME,SIZE | grep -v loop
echo ""
read -p "Disque cible (ex: /dev/sda /dev/nvme0n1): " DISK

if [[ "$DISK" == *nvme* ]] || [[ "$DISK" == *mmcblk* ]]; then
   EFI="${DISK}p1"
   ROOT="${DISK}p2"
else
   EFI="${DISK}1"
   ROOT="${DISK}2"
fi

echo ""
echo "!!! ATTENTION !!!"
echo "Le disque $DISK va être TOTALLEMENT effacé."
echo "Partitions : EFI=$EFI  ROOT=$ROOT"
read -p "Taper OUI pour continuer: " CONFIRM
if [[ "$CONFIRM" != "OUI" ]]; then
   echo "annulé."
   exit 1
fi

# partition
echo "partitionnement..."
parted $DISK --script mklabel gpt
parted $DISK --script mkpart ESP fat32 1MiB 513MiB
parted $DISK --script set 1 esp on
parted $DISK --script mkpart primary ext4 513MiB 100%
sleep 2
partprobe $DISK || true

echo "formatage..."
mkfs.fat -F32 $EFI
mkfs.ext4 -F $ROOT

# montage
mount $ROOT /mnt
mkdir -p /mnt/boot
mount $EFI /mnt/boot

# config nixos
echo "gen config nixos..."
nixos-generate-config --root /mnt
CONF=/mnt/etc/nixos/configuration.nix
sed -i '$ { /^}$/d; }' $CONF

ROOT_PASS="ricoroot"
if command -v openssl >/dev/null 2>&1; then
   ROOT_HASH=$(openssl passwd -6 "$ROOT_PASS" 2>/dev/null || echo "$ROOT_PASS")
else
   ROOT_HASH="$ROOT_PASS"
fi

cat >> $CONF << EOF

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

# install
echo "lancement nixos-install (prends un café)..."
nixos-install --root /mnt --no-root-passwd

echo ""
echo "========================================"
echo "  INSTALL TERMINÉ (normalement)"
echo "========================================"
echo "root password temporaire : $ROOT_PASS"
echo "change ça après premier boot : passwd"
echo "redémarre et retire l'iso."
echo ""

read -p "redémarrer maintenant ? (o/n): " REBOOT
if [[ "$REBOOT" == "o" ]]; then
   reboot
fi
