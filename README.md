# 🔐 Script-client-Windows-Port-Knocking

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://learn.microsoft.com/fr-fr/powershell/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D4?logo=windows)](https://www.microsoft.com/fr-fr/windows)
[![OpenSSH](https://img.shields.io/badge/OpenSSH-requis-green?logo=openssh)](https://learn.microsoft.com/fr-fr/windows-server/administration/openssh/openssh_install_firstuse)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Client **Port Knocking** en PowerShell pour Windows — frappe automatiquement la séquence de ports secrète sur votre serveur, puis ouvre la connexion SSH en une seule commande.

---

## 📋 Table des matières

- [Qu'est-ce que le Port Knocking ?](#-quest-ce-que-le-port-knocking-)
- [Fonctionnement du script](#-fonctionnement-du-script)
- [Prérequis](#-prérequis)
- [Installation](#-installation)
- [Utilisation](#-utilisation)
- [Configuration de la séquence de ports](#-configuration-de-la-séquence-de-ports)
- [Exemple de session](#-exemple-de-session)
- [Dépannage](#-dépannage)
- [Sécurité](#-sécurité)
- [Contribuer](#-contribuer)
- [Licence](#-licence)

---

## 🔍 Qu'est-ce que le Port Knocking ?

Le **Port Knocking** est une technique de sécurité réseau qui consiste à **masquer le port SSH** (ou tout autre service) derrière un pare-feu. Le port reste fermé pour tout le monde tant qu'une séquence secrète de "frappes" TCP n'a pas été envoyée dans le bon ordre.

```
Client                          Serveur (pare-feu actif)
  │                                    │
  │──► TCP SYN → port 60006 (fermé)   │  1re frappe
  │──► TCP SYN → port 40004 (fermé)   │  2e frappe
  │──► TCP SYN → port 55555 (fermé)   │  3e frappe
  │──► TCP SYN → port 44444 (fermé)   │  4e frappe
  │──► TCP SYN → port 50005 (fermé)   │  5e frappe
  │                                    │
  │        (knockd détecte la séquence et ouvre le port SSH)
  │                                    │
  │══► SSH → port 22 (ouvert !)        │  Connexion SSH
```

**Avantages :**
- Le port SSH est **invisible** aux scanners de ports (nmap, shodan…)
- Réduit drastiquement les tentatives de brute-force
- Aucun logiciel supplémentaire côté client (juste PowerShell + OpenSSH)

---

## ⚙️ Fonctionnement du script

Le script `knock-client.ps1` réalise les étapes suivantes :

1. **Vérifie** que le client OpenSSH (`ssh`) est disponible dans le PATH
2. **Demande interactivement** : IP du serveur, port SSH, nom d'utilisateur
3. **Propose** d'utiliser une clé SSH privée (optionnel)
4. **Envoie la séquence de frappes TCP** sur les ports `60006 → 40004 → 55555 → 44444 → 50005`
5. **Attend 2 secondes** pour laisser le démon `knockd`/`fwknop` ouvrir le port
6. **Lance la connexion SSH** avec les paramètres fournis

---

## 🛠️ Prérequis

| Élément | Version minimale | Vérification |
|---|---|---|
| Windows | 10 ou 11 | — |
| PowerShell | 5.1+ (inclus dans Windows) | `$PSVersionTable.PSVersion` |
| Client OpenSSH | Fonctionnalité facultative Windows | `ssh -V` |

### Installer le client OpenSSH (si absent)

**Via les Paramètres Windows (méthode graphique) :**
1. `Paramètres` → `Applications` → `Fonctionnalités facultatives`
2. Cliquer sur `Afficher les fonctionnalités` / `Ajouter une fonctionnalité`
3. Rechercher **Client OpenSSH** et l'installer

**Via PowerShell (méthode rapide, en administrateur) :**
```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

---

## 📥 Installation

### Option 1 — Téléchargement direct

1. Télécharger [`knock-client.ps1`](knock-client.ps1) (bouton **Raw** → Ctrl+S)
2. Placer le fichier dans un répertoire de votre choix, par exemple `C:\Tools\`

### Option 2 — Cloner le dépôt (git requis)

```powershell
git clone https://github.com/NicoBOD/Script-client-Windows-Port-Knocking.git
cd Script-client-Windows-Port-Knocking
```

---

## 🚀 Utilisation

### Lancement standard

Ouvrir **PowerShell** (pas besoin d'être administrateur) et exécuter :

```powershell
.\knock-client.ps1
```

> **Note :** Si PowerShell bloque l'exécution avec une erreur de politique, voir la section [Dépannage](#-dépannage).

### Double-clic depuis l'Explorateur Windows

Faire un **clic droit** sur `knock-client.ps1` → **Exécuter avec PowerShell**

---

## 🔧 Configuration de la séquence de ports

La séquence de ports est définie à la ligne 59 du script :

```powershell
$ports = @(60006, 40004, 55555, 44444, 50005)
```

**Pour adapter cette séquence à votre serveur**, modifiez ce tableau en respectant exactement la séquence configurée dans votre démon `knockd` ou `fwknop` côté serveur.

Exemple de configuration `knockd` correspondante (`/etc/knockd.conf`) :
```ini
[openSSH]
    sequence    = 60006,40004,55555,44444,50005
    seq_timeout = 10
    command     = /sbin/iptables -A INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn
```

---

## 💻 Exemple de session

```
Entrez l'adresse IP du serveur : 203.0.113.42
Entrez le port SSH (par défaut 22) : 2222
Entrez le nom d'utilisateur SSH : alice
Utiliser une clé SSH pour se connecter ? (o/N) : o
Entrez le chemin vers la clé privée (ex: C:\Users\Nom\.ssh\id_rsa) : C:\Users\Alice\.ssh\id_ed25519

Envoi de la séquence de port knocking...
  Frappe sur le port 60006...
  Frappe sur le port 40004...
  Frappe sur le port 55555...
  Frappe sur le port 44444...
  Frappe sur le port 50005...
Séquence terminée. Attente de l'ouverture du port par le serveur...
Lancement de la connexion SSH...

alice@203.0.113.42's password:
```

---

## 🩺 Dépannage

### ❌ `Le fichier ... ne peut pas être chargé car l'exécution de scripts est désactivée`

PowerShell bloque l'exécution de scripts par politique de sécurité. Solutions :

```powershell
# Option A — Autoriser pour la session courante uniquement (recommandé)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Option B — Contourner en ligne de commande
powershell.exe -ExecutionPolicy Bypass -File .\knock-client.ps1
```

### ❌ `'ssh' est introuvable`

Le client OpenSSH n'est pas installé. Voir la section [Prérequis](#-prérequis).

### ❌ La connexion SSH échoue même après le knocking

- Vérifier que la séquence de ports dans le script correspond exactement à celle configurée sur le serveur
- Augmenter le délai d'attente (ligne `Start-Sleep -Seconds 2`) si le serveur est lent à réagir
- Vérifier les logs du serveur : `sudo journalctl -u knockd -f`

### ❌ `Erreur : le fichier de clé privée est introuvable`

Le chemin saisi ne pointe pas vers un fichier existant. Vérifier le chemin avec :
```powershell
Test-Path "C:\Users\VotreNom\.ssh\id_rsa"
```

---

## 🔒 Sécurité

- La séquence de ports est codée en dur dans le script : **ne pas partager publiquement votre version modifiée** si la séquence est secrète.
- Le script ne stocke ni ne transmet aucune information d'authentification — les mots de passe sont gérés directement par le client SSH natif.
- Pour une sécurité maximale, combiner le port knocking avec une **clé SSH** (pas de mot de passe).
- Envisager `fwknop` (Single Packet Authorization) pour une approche encore plus robuste.

---

## 🤝 Contribuer

Les contributions sont les bienvenues !

1. Forker le dépôt
2. Créer une branche : `git checkout -b feature/ma-fonctionnalite`
3. Committer vos changements : `git commit -m "feat: ma fonctionnalité"`
4. Pousser : `git push origin feature/ma-fonctionnalite`
5. Ouvrir une Pull Request

---

## 📄 Licence

Ce projet est distribué sous licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

© 2026 Nicolas BODAINE