# 📚 Tutoriel pédagogique — Port Knocking sous Windows avec PowerShell

Ce tutoriel vous guide pas à pas, de zéro, pour comprendre et utiliser le script `knock-client.ps1`.

---

## Partie 1 — Comprendre le Port Knocking

### 1.1 Pourquoi votre port SSH est-il une cible ?

Lorsque vous exposez un serveur SSH sur Internet, des robots automatisés le détectent en quelques heures et tentent des milliers de connexions avec des mots de passe courants (*brute-force*). C'est visible dans les logs :

```
Failed password for root from 185.x.x.x port 54321 ssh2
Failed password for admin from 91.x.x.x port 12345 ssh2
...
```

### 1.2 La solution : rendre le port invisible

Le **Port Knocking** consiste à :
1. **Fermer le port SSH** au niveau du pare-feu (iptables, nftables…)
2. Configurer un démon (`knockd`) qui **surveille les tentatives de connexion** sur des ports spécifiques
3. Quand la **bonne séquence** de tentatives est détectée (dans le bon ordre, dans le bon délai), le démon **ouvre dynamiquement** le port SSH uniquement pour cette IP
4. Le client peut alors se connecter en SSH

```
SANS port knocking          AVEC port knocking
─────────────────           ──────────────────
Port 22 : OUVERT            Port 22 : FERMÉ (invisible)
→ scannable                 → knock avec la bonne séquence
→ attaques brute-force      → Port 22 s'ouvre pour votre IP
                            → connexion SSH réussie
```

### 1.3 La séquence secrète

La séquence est une liste ordonnée de ports TCP, par exemple :
```
60006 → 40004 → 55555 → 44444 → 50005
```

Seul quelqu'un connaissant **exactement** cette séquence (et son ordre) peut déclencher l'ouverture. Les tentatives de connexion sur ces ports semblent normalement échouer (connexion refusée) — c'est **intentionnel et attendu**.

---

## Partie 2 — Préparer votre environnement Windows

### 2.1 Vérifier la version de PowerShell

Ouvrir PowerShell (`Win + R` → taper `powershell` → Entrée) et exécuter :

```powershell
$PSVersionTable.PSVersion
```

Vous devriez voir `Major` ≥ 5. Exemple de sortie :
```
Major  Minor  Build  Revision
-----  -----  -----  --------
5      1      19041  4522
```

### 2.2 Installer le client OpenSSH

Dans une fenêtre PowerShell **en tant qu'administrateur** (`clic droit` sur PowerShell → `Exécuter en tant qu'administrateur`) :

```powershell
# Vérifier si OpenSSH est déjà installé
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
```

Si l'état est `NotPresent`, installer :

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

Vérifier l'installation :

```powershell
ssh -V
# Résultat attendu : OpenSSH_for_Windows_9.x.x ...
```

### 2.3 Télécharger le script

**Méthode A — Via PowerShell :**
```powershell
# Créer un dossier dédié
New-Item -ItemType Directory -Path "$env:USERPROFILE\Tools" -Force

# Télécharger le script
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/NicoBOD/Script-client-Windows-Port-Knocking/main/knock-client.ps1" `
  -OutFile "$env:USERPROFILE\Tools\knock-client.ps1"
```

**Méthode B — Via git :**
```powershell
git clone https://github.com/NicoBOD/Script-client-Windows-Port-Knocking.git "$env:USERPROFILE\Tools\port-knocking"
```

---

## Partie 3 — Configurer la séquence de ports

Avant de lancer le script, vous devez vous assurer que la séquence dans le script **correspond à celle de votre serveur**.

### 3.1 Ouvrir le script dans un éditeur

```powershell
# Avec le Bloc-notes
notepad "$env:USERPROFILE\Tools\knock-client.ps1"

# Avec VS Code (si installé)
code "$env:USERPROFILE\Tools\knock-client.ps1"
```

### 3.2 Repérer la ligne de séquence

```powershell
# Ligne 59 du script
$ports = @(60006, 40004, 55555, 44444, 50005)
```

### 3.3 Adapter à votre serveur

Remplacer les nombres par votre propre séquence. Par exemple, si votre serveur utilise `1111 → 2222 → 3333` :

```powershell
$ports = @(1111, 2222, 3333)
```

> ⚠️ Cette séquence doit correspondre **exactement** à celle configurée dans `knockd.conf` sur votre serveur.

---

## Partie 4 — Lancer le script

### 4.1 Ouvrir PowerShell dans le bon dossier

**Méthode 1 — Depuis l'Explorateur Windows :**
1. Naviguer jusqu'au dossier contenant `knock-client.ps1`
2. Cliquer dans la barre d'adresse, taper `powershell`, appuyer sur Entrée

**Méthode 2 — Depuis PowerShell :**
```powershell
cd "$env:USERPROFILE\Tools"
```

### 4.2 Gérer la politique d'exécution

Windows bloque par défaut l'exécution de scripts. Pour **cette session uniquement** :

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### 4.3 Exécuter le script

```powershell
.\knock-client.ps1
```

### 4.4 Répondre aux questions interactives

Le script vous pose 4 questions :

---

**Question 1 — Adresse IP du serveur**
```
Entrez l'adresse IP du serveur :
```
→ Saisir l'IP de votre serveur, ex : `203.0.113.42`

---

**Question 2 — Port SSH**
```
Entrez le port SSH (par défaut 22) :
```
→ Appuyer sur Entrée pour utiliser le port 22, ou saisir un port personnalisé ex : `2222`

---

**Question 3 — Nom d'utilisateur**
```
Entrez le nom d'utilisateur SSH :
```
→ Saisir votre identifiant, ex : `alice`

---

**Question 4 — Clé SSH (optionnel)**
```
Utiliser une clé SSH pour se connecter ? (o/N)
```
→ `o` pour utiliser une clé privée, ou Entrée/`n` pour une connexion par mot de passe

Si vous répondez `o` :
```
Entrez le chemin vers la clé privée (ex: C:\Users\Nom\.ssh\id_rsa) :
```
→ Saisir le chemin complet vers votre clé, ex : `C:\Users\Alice\.ssh\id_ed25519`

---

### 4.5 Suivre l'exécution

```
Envoi de la séquence de port knocking...
  Frappe sur le port 60006...       ← tentative TCP (rejet attendu)
  Frappe sur le port 40004...       ← tentative TCP (rejet attendu)
  Frappe sur le port 55555...       ← tentative TCP (rejet attendu)
  Frappe sur le port 44444...       ← tentative TCP (rejet attendu)
  Frappe sur le port 50005...       ← tentative TCP (rejet attendu)
Séquence terminée. Attente de l'ouverture du port par le serveur...
                                     ← pause de 2 secondes
Lancement de la connexion SSH...
alice@203.0.113.42's password:       ← SSH interactif
```

---

## Partie 5 — Configurer une clé SSH (recommandé)

Utiliser une clé SSH à la place d'un mot de passe est bien plus sécurisé.

### 5.1 Générer une paire de clés

```powershell
# Créer le dossier .ssh s'il n'existe pas
New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" -Force

# Générer une clé Ed25519 (algorithme moderne et sécurisé)
ssh-keygen -t ed25519 -C "votre@email.com" -f "$env:USERPROFILE\.ssh\id_ed25519"
```

Cela crée :
- `~\.ssh\id_ed25519` — **clé privée** (à ne jamais partager)
- `~\.ssh\id_ed25519.pub` — **clé publique** (à copier sur le serveur)

### 5.2 Copier la clé publique sur le serveur

```powershell
# Afficher la clé publique
Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
```

Copier cette ligne sur le serveur dans `~/.ssh/authorized_keys`.

Ou utiliser la commande tout-en-un (nécessite une première connexion par mot de passe) :
```powershell
# Après avoir effectué le knocking manuellement une première fois :
ssh-copy-id -i "$env:USERPROFILE\.ssh\id_ed25519.pub" alice@203.0.113.42
```

### 5.3 Tester la connexion avec clé

Au prochain lancement de `knock-client.ps1`, répondre `o` à la question sur la clé SSH et fournir le chemin `C:\Users\Alice\.ssh\id_ed25519`.

---

## Partie 6 — Automatiser avec un raccourci Windows

Pour lancer le script d'un double-clic :

1. Faire un **clic droit** sur le Bureau → `Nouveau` → `Raccourci`
2. Dans "Emplacement", saisir :
   ```
   powershell.exe -ExecutionPolicy Bypass -NoExit -File "C:\Users\Alice\Tools\knock-client.ps1"
   ```
3. Nommer le raccourci : `SSH Port Knocking`
4. (Optionnel) Changer l'icône : clic droit sur le raccourci → `Propriétés` → `Changer d'icône`

---

## Partie 7 — Résolution de problèmes courants

### Scénario A : Le port SSH ne s'ouvre pas

**Symptôme :** La séquence se déroule sans erreur, mais SSH donne `Connection refused` ou `Connection timed out`.

**Vérifications :**
1. La séquence dans le script correspond-elle à `knockd.conf` sur le serveur ?
2. Le délai de 2 secondes est-il suffisant ? Essayer d'augmenter :
   ```powershell
   # Ligne 98 du script
   Start-Sleep -Seconds 5
   ```
3. Les logs du serveur donnent-ils des indices ?
   ```bash
   sudo journalctl -u knockd --since "5 minutes ago"
   # ou
   sudo tail -f /var/log/syslog | grep knock
   ```

### Scénario B : Erreur de politique d'exécution

**Symptôme :**
```
.\knock-client.ps1 : Le fichier ... ne peut pas être chargé car l'exécution
de scripts est désactivée sur ce système.
```

**Solution :**
```powershell
# Contournement pour la session en cours
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\knock-client.ps1
```

### Scénario C : La clé SSH n'est pas acceptée

**Vérifier les permissions sur le serveur :**
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

**Vérifier que la clé publique est bien dans `authorized_keys` :**
```bash
cat ~/.ssh/authorized_keys
```

### Scénario D : Timeout réseau pendant le knocking

Si votre réseau filtre agressivement les paquets sortants, essayer d'augmenter le timeout de connexion TCP dans le script (ligne 80) :
```powershell
# De 100 ms à 500 ms
$IAsyncResult.AsyncWaitHandle.WaitOne(500) | Out-Null
```

---

## Récapitulatif

| Étape | Action |
|-------|--------|
| 1 | Installer le client OpenSSH Windows |
| 2 | Télécharger `knock-client.ps1` |
| 3 | Adapter la séquence de ports (ligne 59) |
| 4 | Ouvrir PowerShell et exécuter `.\knock-client.ps1` |
| 5 | Répondre aux 4 questions interactives |
| 6 | La connexion SSH s'établit automatiquement |

---

*Tutoriel rédigé pour le projet [Script-client-Windows-Port-Knocking](https://github.com/NicoBOD/Script-client-Windows-Port-Knocking) — © 2026 Nicolas BODAINE — Licence MIT*
