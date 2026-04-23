# Demande à l'utilisateur l'adresse IP du serveur
$targetHost = Read-Host "Entrez l'adresse IP du serveur"

# Demande à l'utilisateur le port SSH
$sshPort = Read-Host "Entrez le port SSH (par defaut 22)"

# Si l'utilisateur ne rentre pas de port, utiliser le port 22 par défaut
if ([string]::IsNullOrWhiteSpace($sshPort)) {
    $sshPort = 22
}

# Demande à l'utilisateur le nom d'utilisateur pour la connexion SSH
$username = Read-Host "Entrez le nom d'utilisateur SSH"

# Demande à l'utilisateur s'il utilise une clé SSH
$useKey = Read-Host "Utiliser une clé SSH pour se connecter ? (o/N)"
$keyPath = ""

if ($useKey -match "^[oO]") {
    $keyPath = Read-Host "Entrez le chemin vers la clé privée (ex: C:\Users\Nom\.ssh\id_rsa)"
}

# Définis la séquence de ports à frapper pour le port knocking (écrite en dur)
$ports = @(60006, 40004, 55555, 44444, 50005)

Write-Host "Envoi de la séquence de port knocking..." -ForegroundColor Cyan

# Commence une boucle pour parcourir chaque port dans la séquence
foreach ($port in $ports) {
    try {
        # Crée un nouveau client TCP pour établir une connexion
        $client = New-Object System.Net.Sockets.TcpClient
    
        # Tente de se connecter à l'hôte cible sur le port actuel
        $IAsyncResult = $client.BeginConnect($targetHost, $port, $null, $null)
    
        # Attends pendant 100 millisecondes pour laisser le temps à la connexion d'être établie (et au paquet SYN de partir)
        Start-Sleep -Milliseconds 100
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

Write-Host "Séquence terminée. Lancement de la connexion SSH..." -ForegroundColor Green

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
