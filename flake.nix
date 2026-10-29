# ═══════════════════════════════════════════════════════════════
#  LFS-Nix — un « Linux From Scratch » basé sur NixOS
#  Tout est compilé depuis les sources : aucun cache binaire.
#
#  Dans le dossier qui contient ce fichier :
#
#  1) Tester dans une VM (rien n'est installé sur ton disque)
#       nix build .#vm --option substitute false -L
#       ./result/bin/run-lfs-vm      # login : lfs / lfs — quitter : Ctrl-A puis X
#
#  2) Installer pour de vrai — sur un disque DÉDIÉ (⚠ efface tout)
#     Remplace /dev/sdX par ton disque (voir lsblk ; NVMe : /dev/nvme0n1p1…).
#     SSD interne conseillé : le build écrit des dizaines de Go.
#       sudo parted /dev/sdX -- mklabel gpt
#       sudo parted /dev/sdX -- mkpart ESP fat32 1MiB 1GiB
#       sudo parted /dev/sdX -- set 1 esp on
#       sudo parted /dev/sdX -- mkpart root ext4 1GiB 100%
#       sudo mkfs.fat -F 32 -n LFSBOOT /dev/sdX1
#       sudo mkfs.ext4 -L lfs /dev/sdX2
#       sudo mkdir -p /mnt/lfs
#       sudo mount /dev/disk/by-label/lfs /mnt/lfs
#       sudo mkdir -p /mnt/lfs/boot
#       sudo mount /dev/disk/by-label/LFSBOOT /mnt/lfs/boot
#       sudo nixos-install --root /mnt/lfs --flake .#lfs \
#         --option substitute false --no-root-passwd
#
#  Prévois plusieurs heures de compilation et ~60 Go libres.
# ═══════════════════════════════════════════════════════════════
{
  description = "LFS-Nix : NixOS compilé depuis les sources, kernel CachyOS";

  inputs = {
    # Kernel CachyOS. On utilise SON nixpkgs : les patchs doivent coller
    # exactement à la version du kernel (ne pas le remplacer).
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    nixpkgs.follows = "nix-cachyos-kernel/nixpkgs";
  };

  outputs = { self, nixpkgs, nix-cachyos-kernel, ... }:
    let
      # true  = kernel CachyOS (variante sans LTO, donc sans Clang/LLVM)
      # false = kernel Linux standard de nixpkgs (pour isoler un problème)
      useCachyKernel = false;
    in
    {
      nixosConfigurations.lfs = nixpkgs.lib.nixosSystem {
        modules = [
          ({ lib, pkgs, ... }: {
            nixpkgs.hostPlatform = { system = "x86_64-linux"; gcc.arch = "x86-64-v3"; };
            nixpkgs.overlays = [ nix-cachyos-kernel.overlays.default ];

            # ── Identité ────────────────────────────────────────
            networking.hostName = "lfs";
            system.nixos.distroName = "LFS-Nix";
            system.stateVersion = "26.05";

            # ── Kernel (compilé ici) ────────────────────────────
            boot.kernelPackages =
              if useCachyKernel
              then pkgs.cachyosKernels.linuxPackages-cachyos-latest
              else pkgs.linuxPackages_latest;

            # ── Aucun binaire téléchargé : tout se compile ──────
            nix.settings = {
              substituters = lib.mkForce [ ];
              experimental-features = [ "nix-command" "flakes" ];
            };

            # ── Démarrage UEFI, disques repérés par leur label ──
            boot.loader.systemd-boot.enable = true;
            # true si tu installes sur le disque interne (enregistre l'entrée de boot)
            boot.loader.efi.canTouchEfiVariables = false;
            fileSystems."/" = {
              device = "/dev/disk/by-label/lfs";
              fsType = "ext4";
            };
            fileSystems."/boot" = {
              device = "/dev/disk/by-label/LFSBOOT";
              fsType = "vfat";
              options = [ "fmask=0077" "dmask=0077" ];
            };

            # ── Système minimal (moins de choses à compiler) ────
            documentation.enable = false;
            programs.command-not-found.enable = false;
            environment.defaultPackages = [ ];
            environment.systemPackages = with pkgs; [ git htop fastfetch ];

            # ── Clavier AZERTY + utilisateur lfs / lfs ──────────
            # (change le mot de passe au premier login avec `passwd`)
            console.keyMap = "fr";
            users.users.lfs = {
              isNormalUser = true;
              extraGroups = [ "wheel" ];
              initialPassword = "lfs";
            };

            # ── VM de test ──────────────────────────────────────
            virtualisation.vmVariant.virtualisation = {
              diskSize = 80 * 1024;   # en Mo : 80 Go
              graphics = false;   # console dans ton terminal
              memorySize = 4096;
              cores = 4;
              # qemu sans interface graphique : évite de compiler GTK/Mesa/LLVM
              qemu.package = pkgs.qemu_test;
            };
          })
        ];
      };
      nixosConfigurations.ricOS-iso = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";

  modules = [
    "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"

    ({ pkgs, lib, ... }: {
      networking.hostName = "ricos-live";
      # Identité RicOS dans le menu de démarrage
system.nixos.distroName = "RicOS";
isoImage.configurationName = "Live USB";
services.getty.greetingLine = "Welcome to RicOS 1.0!";
system.nixos.label = "RicOS-1.0";

# Thème GRUB pour l'ISO UEFI
isoImage.grubTheme = ./grub-theme;

# Laisser le temps de choisir une option
boot.loader.timeout = 10;

      isoImage.isoName = "RicOS-Live.iso";

      services.xserver.enable = false;
      networking.networkmanager.enable = true;
      environment.etc."ricos-logo.txt".source = ./ricos-logo-nixos-size.txt;     

      users.users.live = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        initialPassword = "live";
      };

      services.getty.autologinUser = lib.mkForce "live";

      environment.systemPackages = with pkgs; [
  fastfetch
  nano
  git
  htop
  dialog
  networkmanager

  (writeShellApplication {
    name = "ricos-install";

    runtimeInputs = [
      bash
      dialog
      util-linux
      networkmanager
    ];

    text = builtins.readFile ./installer/ricos-install;
  })
];
      environment.etc."fastfetch/config.jsonc".text =
  builtins.toJSON {
    logo = {
  type = "file";
  source = "/etc/ricos-logo.txt";
  color = {
    "1" = "cyan";
  };
};

    display.separator = " -> ";

    modules = [
      {
        type = "custom";
        format = "RicOS";
      }
      "break"
      {
        type = "os";
        key = "OS";
        format = "RicOS 1.0";
      }
      "host"
      "kernel"
      "uptime"
      "packages"
      "shell"
      "cpu"
      "gpu"
      "memory"
      "disk"
    ];
  };

programs.bash.interactiveShellInit = ''
  if [ -t 1 ] && command -v fastfetch >/dev/null; then
    fastfetch --config /etc/fastfetch/config.jsonc
  fi
  '';
     
    })
  ];
};

      
      packages.x86_64-linux = {
        vm = self.nixosConfigurations.lfs.config.system.build.vm;
        toplevel = self.nixosConfigurations.lfs.config.system.build.toplevel;
        # ISO live RicOS :  nix build .#iso
        iso = self.nixosConfigurations.ricOS-iso.config.system.build.isoImage;
      };
    };
}
