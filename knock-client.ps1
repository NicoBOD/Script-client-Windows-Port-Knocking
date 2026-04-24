# Vérifie que le client OpenSSH est disponible dans le PATH avant de continuer
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host "Erreur : 'ssh' est introuvable. Veuillez installer le client OpenSSH (Paramètres > Applications > Fonctionnalités facultatives > Client OpenSSH)." -ForegroundColor Red
    Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
    exit 1
}

# Demande à l'utilisateur l'adresse IP du serveur (relance la demande si vide)
do {
    $targetHost = Read-Host "Entrez l'adresse IP du serveur"
    if ([string]::IsNullOrWhiteSpace($targetHost)) {
        Write-Host "Erreur : l'adresse IP du serveur est requise." -ForegroundColor Red
    }
} while ([string]::IsNullOrWhiteSpace($targetHost))

# Demande à l'utilisateur le port SSH (relance la demande si invalide)
$validPort = $false
do {
    $sshPort = Read-Host "Entrez le port SSH (par défaut 22)"
    if ([string]::IsNullOrWhiteSpace($sshPort)) {
        $sshPort = 22
        $validPort = $true
    } elseif ($sshPort -notmatch '^\d+$' -or [int]$sshPort -lt 1 -or [int]$sshPort -gt 65535) {
        Write-Host "Erreur : le port SSH doit être un entier compris entre 1 et 65535." -ForegroundColor Red
    } else {
        $sshPort = [int]$sshPort
        $validPort = $true
    }
} while (-not $validPort)

# Demande à l'utilisateur le nom d'utilisateur pour la connexion SSH (relance la demande si vide)
do {
    $username = Read-Host "Entrez le nom d'utilisateur SSH"
    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host "Erreur : le nom d'utilisateur SSH est requis." -ForegroundColor Red
    }
} while ([string]::IsNullOrWhiteSpace($username))

# Demande à l'utilisateur s'il utilise une clé SSH
$useKey = Read-Host "Utiliser une clé SSH pour se connecter ? (o/N)"
$keyPath = ""

if ($useKey -match "^[oO]") {
    $validKey = $false
    do {
        $keyPath = Read-Host "Entrez le chemin vers la clé privée (ex: C:\Users\Nom\.ssh\id_rsa)"
        if (Test-Path $keyPath -PathType Container) {
            Write-Host "Erreur : le chemin spécifié est un dossier, pas un fichier. Veuillez entrer le chemin complet vers le fichier de clé privée (ex: C:\Users\Nom\.ssh\id_rsa)." -ForegroundColor Red
        } elseif (-not (Test-Path $keyPath)) {
            Write-Host "Erreur : le fichier de clé privée est introuvable : $keyPath" -ForegroundColor Red
        } else {
            $validKey = $true
        }
    } while (-not $validKey)
}

# Définis la séquence de ports à frapper pour le port knocking (écrite en dur)
$ports = @(60006, 40004, 55555, 44444, 50005)

Write-Host "Envoi de la séquence de port knocking..." -ForegroundColor Cyan

# Commence une boucle pour parcourir chaque port dans la séquence
foreach ($port in $ports) {
    # Initialisation explicite à $null : si New-Object échoue, le bloc finally
    # doit trouver $client à $null pour éviter d'appeler Close() sur une valeur résiduelle
    $client = $null
    try {
        Write-Host "  Frappe sur le port $port..." -ForegroundColor DarkCyan

        # Crée un nouveau client TCP pour établir une connexion
        $client = New-Object System.Net.Sockets.TcpClient

        # Tente de se connecter à l'hôte cible sur le port actuel de façon asynchrone
        $IAsyncResult = $client.BeginConnect($targetHost, $port, $null, $null)

        # Attend au maximum 50 ms que la réponse du serveur arrive.
        # Si WaitOne retourne $true, l'opération async est terminée (RST reçu) et EndConnect est
        # appelé pour libérer les ressources. Si WaitOne retourne $false (timeout, SYN silencieusement
        # ignoré par le firewall), EndConnect est volontairement ignoré : l'appeler sur une opération
        # async non terminée bloquerait le script pendant plusieurs secondes (timeout TCP de l'OS).
        # La fermeture du socket dans le bloc finally annule immédiatement l'opération en cours.
        $connected = $IAsyncResult.AsyncWaitHandle.WaitOne(50)
        if ($connected) {
            try { $client.EndConnect($IAsyncResult) } catch {}
        }
    }
    catch {
        # Les erreurs sont silencieusement ignorées car le port est fermé (comportement attendu du port knocking)
    }
    finally {
        # Ferme la connexion client TCP
        if ($client -ne $null) {
            $client.Close()
        }
    }
}

Write-Host "Séquence terminée. Attente de l'ouverture du port par le serveur..." -ForegroundColor Yellow

# Laisse le temps au démon de port knocking (knockd/fwknop) de traiter la séquence
# et d'ouvrir le port avant de lancer la connexion SSH
Start-Sleep -Seconds 2

Write-Host "Lancement de la connexion SSH..." -ForegroundColor Green

# Construction des arguments pour la commande SSH
$sshArgs = @("-p", $sshPort)

if (-not [string]::IsNullOrWhiteSpace($keyPath)) {
    $sshArgs += "-i"
    $sshArgs += $keyPath
}

$sshArgs += "$username@$targetHost"

# Exécute la commande SSH de manière native via l'opérateur d'appel "&". 
# Ceci préserve l'interactivité complète (TTY) essentielle pour les prompts 
# de mot de passe, de phrase de passe de clé SSH et d'authentification 2FA.
& ssh $sshArgs

# Met le script en pause pour ne pas fermer la fenêtre brutalement après la déconnexion
Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
