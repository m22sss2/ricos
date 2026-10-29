# RicOS 1.0

**RicOS** est mon OS open source basé sur **NixOS**, entièrement *vibecodé* : construit à l'intuition, avec l'aide d'une IA, en expérimentant.

> ⚠️ Projet expérimental. Ça marche pour moi, mais attends-toi à des bugs et à des changements. Pas encore prêt pour un usage quotidien.

## Contenu

| Élément | Description |
|---|---|
| **ISO live RicOS** | ISO minimale NixOS avec identité RicOS (nom, logo fastfetch, thème GRUB, message d'accueil) |
| **`ricos-install`** | Pas d'installateur pour le moment (la commande affiche seulement un message) |
| **LFS-Nix** (`.#lfs`) | Variante « Linux From Scratch » : NixOS compilé depuis les sources, sans cache binaire |

## Prérequis

- [Nix](https://nixos.org/download) avec les flakes activés (`experimental-features = nix-command flakes`)
- Linux x86_64 (ou une VM)

## Construire l'ISO live

```bash
nix build .#iso
# l'ISO se trouve dans ./result/iso/RicOS-Live.iso
```

Tester dans QEMU :

```bash
qemu-system-x86_64 -enable-kvm -m 4G -cdrom result/iso/RicOS-Live.iso
```

Identifiants du live : `live` / `live` (autologin).

## Tester LFS-Nix dans une VM

```bash
nix build .#vm --option substitute false -L
./result/bin/run-lfs-vm      # login : lfs / lfs — quitter : Ctrl-A puis X
```

Prévois plusieurs heures de compilation et ~60 Go libres. Les instructions d'installation sur disque réel sont en commentaire au début de `flake.nix`.
**⚠️ Elles effacent le disque cible : vérifie bien `/dev/sdX`.**

Si une source amont est introuvable (404, connexion coupée), tu peux pré-télécharger les sources depuis le cache NixOS :

```bash
bash scripts/prefetch-sources.sh
```

## Structure

```
flake.nix / flake.lock   configuration principale (ISO RicOS + LFS-Nix)
grub-theme/              thème GRUB de l'ISO
installer/ricos-install  installateur (démo)
scripts/                 scripts utilitaires
ricos-logo-*.txt         logos ASCII pour fastfetch
```

## Sécurité

Les mots de passe par défaut (`live/live`, `lfs/lfs`) sont là pour les tests. Change-les (`passwd`) avant tout usage réel.

## Feuille de route

- [ ] Installation réelle sur disque (partitionnement, `nixos-install`)
- [ ] Captures d'écran
- [ ] Releases avec ISO prête à l'emploi

## Licence

[MIT](LICENSE)
