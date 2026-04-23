# Demande à l'utilisateur l'adresse IP du serveur
$targetHost = Read-Host "Entrez l'adresse IP du serveur"

# Demande à l'utilisateur le port SSH
$sshPort = Read-Host "Entrez le port SSH (par defaut 22)"

# Si l'utilisateur ne rentre pas de port, utiliser le port 22 par défaut
if ([string]::IsNullOrEmpty($sshPort)) {
    $sshPort = 22
}

# Demande à l'utilisateur le nom d'utilisateur pour la connexion SSH
$username = Read-Host "Entrez le nom d'utilisateur SSH"

# Définis la séquence de ports à frapper pour le port knocking (écrite en dur)
$ports = @(60006, 40004, 55555, 44444, 50005)

# Commence une boucle pour parcourir chaque port dans la séquence
foreach ($port in $ports) {

    # Crée un nouveau client TCP pour établir une connexion
    $client = New-Object System.Net.Sockets.TcpClient

    # Tente de se connecter à l'hôte cible sur le port actuel
    $IAsyncResult = $client.BeginConnect($targetHost, $port, $null, $null)

    # Attends pendant 100 millisecondes pour laisser le temps à la connexion d'être établie
    Start-Sleep -Milliseconds 100

    # Ferme la connexion client TCP
    $client.Close()
}

# Construction de la commande SSH en utilisant les informations saisies par l'utilisateur
$sshCommand = "ssh -p $sshPort $username@$targetHost"

# Exécute la commande SSH pour se connecter au serveur après le knocking
Invoke-Expression $sshCommand

# Attends 60 secondes pour une entrée utilisateur, ferme si aucune réponse

$input = Read-Host -Prompt "Appuyez sur Entrée pour fermer la fenêtre (timeout 60 secondes)" -Timeout 60