# Demande à l'utilisateur l'adresse IP du serveur
$targetHost = Read-Host "Entrez l'adresse IP du serveur"

# Valide que l'adresse IP n'est pas vide
if ([string]::IsNullOrWhiteSpace($targetHost)) {
    Write-Host "Erreur : l'adresse IP du serveur est requise." -ForegroundColor Red
    Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
    exit 1
}

# Propose à l'utilisateur ce qu'il souhaite faire après le port knocking
Write-Host ""
Write-Host "Que souhaitez-vous faire après le port knocking ?" -ForegroundColor White
Write-Host "  1) Connexion SSH"
Write-Host "  2) Connexion RDP"
Write-Host "  3) Ouvrir en HTTP"
Write-Host "  4) Ouvrir en HTTPS"
Write-Host "  5) Toquer aux ports uniquement (ne rien faire d'autre)"
Write-Host ""

$actionChoice = Read-Host "Votre choix (1-5)"

if ($actionChoice -notmatch '^[1-5]$') {
    Write-Host "Erreur : choix invalide. Veuillez entrer un chiffre entre 1 et 5." -ForegroundColor Red
    Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
    exit 1
}

# Collecte des paramètres spécifiques à l'action choisie
if ($actionChoice -eq "1") {
    # --- SSH ---

    # Vérifie que le client OpenSSH est disponible dans le PATH avant de continuer
    if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
        Write-Host "Erreur : 'ssh' est introuvable. Veuillez installer le client OpenSSH (Paramètres > Applications > Fonctionnalités facultatives > Client OpenSSH)." -ForegroundColor Red
        Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
        exit 1
    }

    # Demande à l'utilisateur le port SSH
    $sshPort = Read-Host "Entrez le port SSH (par défaut 22)"

    if ([string]::IsNullOrWhiteSpace($sshPort)) {
        $sshPort = 22
    } else {
        if ($sshPort -notmatch '^\d+$' -or [int]$sshPort -lt 1 -or [int]$sshPort -gt 65535) {
            Write-Host "Erreur : le port SSH doit être un entier compris entre 1 et 65535." -ForegroundColor Red
            Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
            exit 1
        }
        $sshPort = [int]$sshPort
    }

    # Demande à l'utilisateur le nom d'utilisateur pour la connexion SSH
    $username = Read-Host "Entrez le nom d'utilisateur SSH"

    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host "Erreur : le nom d'utilisateur SSH est requis." -ForegroundColor Red
        Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
        exit 1
    }

    # Demande à l'utilisateur s'il utilise une clé SSH
    $useKey = Read-Host "Utiliser une clé SSH pour se connecter ? (o/N)"
    $keyPath = ""

    if ($useKey -match "^[oO]") {
        $keyPath = Read-Host "Entrez le chemin vers la clé privée (ex: C:\Users\Nom\.ssh\id_rsa)"
        if (-not (Test-Path $keyPath)) {
            Write-Host "Erreur : le fichier de clé privée est introuvable : $keyPath" -ForegroundColor Red
            Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
            exit 1
        }
    }
}
elseif ($actionChoice -eq "2") {
    # --- RDP ---

    # Demande à l'utilisateur le port RDP
    $rdpPort = Read-Host "Entrez le port RDP (par défaut 3389)"

    if ([string]::IsNullOrWhiteSpace($rdpPort)) {
        $rdpPort = 3389
    } else {
        if ($rdpPort -notmatch '^\d+$' -or [int]$rdpPort -lt 1 -or [int]$rdpPort -gt 65535) {
            Write-Host "Erreur : le port RDP doit être un entier compris entre 1 et 65535." -ForegroundColor Red
            Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
            exit 1
        }
        $rdpPort = [int]$rdpPort
    }
}
elseif ($actionChoice -eq "3") {
    # --- HTTP ---

    # Demande à l'utilisateur le port HTTP
    $httpPort = Read-Host "Entrez le port HTTP (par défaut 80)"

    if ([string]::IsNullOrWhiteSpace($httpPort)) {
        $httpPort = 80
    } else {
        if ($httpPort -notmatch '^\d+$' -or [int]$httpPort -lt 1 -or [int]$httpPort -gt 65535) {
            Write-Host "Erreur : le port HTTP doit être un entier compris entre 1 et 65535." -ForegroundColor Red
            Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
            exit 1
        }
        $httpPort = [int]$httpPort
    }
}
elseif ($actionChoice -eq "4") {
    # --- HTTPS ---

    # Demande à l'utilisateur le port HTTPS
    $httpsPort = Read-Host "Entrez le port HTTPS (par défaut 443)"

    if ([string]::IsNullOrWhiteSpace($httpsPort)) {
        $httpsPort = 443
    } else {
        if ($httpsPort -notmatch '^\d+$' -or [int]$httpsPort -lt 1 -or [int]$httpsPort -gt 65535) {
            Write-Host "Erreur : le port HTTPS doit être un entier compris entre 1 et 65535." -ForegroundColor Red
            Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
            exit 1
        }
        $httpsPort = [int]$httpsPort
    }
}
# Choix 5 : aucun paramètre supplémentaire nécessaire

# Définis la séquence de ports à frapper pour le port knocking (écrite en dur)
$ports = @(60006, 40004, 55555, 44444, 50005)

Write-Host ""
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

        # Attend au maximum 100 ms que le paquet SYN parte, puis termine proprement l'opération asynchrone.
        # EndConnect est appelé dans son propre try/catch : une exception ici est attendue car les ports
        # de knocking sont fermés par définition — c'est le comportement normal du port knocking.
        $IAsyncResult.AsyncWaitHandle.WaitOne(100) | Out-Null
        try { $client.EndConnect($IAsyncResult) } catch {}
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

Write-Host "Séquence terminée." -ForegroundColor Yellow

# Lance l'action choisie, ou quitte directement si l'utilisateur a choisi de toquer uniquement
if ($actionChoice -eq "5") {
    Write-Host "Port knocking effectué. Aucune connexion lancée." -ForegroundColor Green
    Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
    exit 0
}

# Laisse le temps au démon de port knocking (knockd/fwknop) de traiter la séquence
# et d'ouvrir le port avant de lancer l'action
Write-Host "Attente de l'ouverture du port par le serveur..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

if ($actionChoice -eq "1") {
    # --- Connexion SSH ---
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
}
elseif ($actionChoice -eq "2") {
    # --- Connexion RDP ---
    Write-Host "Lancement de la connexion RDP vers ${targetHost}:${rdpPort}..." -ForegroundColor Green

    # mstsc accepte l'adresse au format hôte:port directement
    & mstsc /v:"${targetHost}:${rdpPort}"
}
elseif ($actionChoice -eq "3") {
    # --- Ouverture HTTP ---
    $httpUrl = "http://${targetHost}:${httpPort}"
    Write-Host "Ouverture de $httpUrl dans le navigateur par défaut..." -ForegroundColor Green
    Start-Process $httpUrl
}
elseif ($actionChoice -eq "4") {
    # --- Ouverture HTTPS ---
    $httpsUrl = "https://${targetHost}:${httpsPort}"
    Write-Host "Ouverture de $httpsUrl dans le navigateur par défaut..." -ForegroundColor Green
    Start-Process $httpsUrl
}

# Met le script en pause pour ne pas fermer la fenêtre brutalement après l'action
Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre"
