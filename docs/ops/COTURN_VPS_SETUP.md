# Guide Complet : Coturn Self-Hosted sur Hostinger VPS

Configuration d'un serveur TURN/STUN pour l'application **diaspo_niger** avec TLS sur `turn.diasponiger.com`.

---

## Étape 1 : Acheter le VPS Hostinger

### 1.1 Commander le VPS
1. Allez sur https://www.hostinger.fr/vps-hosting
2. Choisissez le plan **KVM 1** (~5.99€/mois)
   - 1 vCPU, 4 Go RAM, 50 Go SSD
3. Lors de la configuration :
   - **OS** : Ubuntu 22.04 LTS (recommandé)
   - **Localisation** : Europe (France ou Pays-Bas pour la latence)
4. Notez votre **adresse IP publique** après la création

---

## Étape 2 : Configuration DNS

### 2.1 Créer le sous-domaine
Dans le panneau DNS de votre domaine `diasponiger.com` :

| Type | Nom | Valeur | TTL |
|------|-----|--------|-----|
| A | turn | `72.62.212.223` | 3600 |

> [!NOTE]
> La propagation DNS peut prendre jusqu'à 24h, mais généralement 5-30 minutes.

---

## Étape 3 : Connexion au VPS

### 3.1 Connexion SSH
```bash
ssh root@VOTRE_IP_VPS
```

### 3.2 Mise à jour du système
```bash
apt update && apt upgrade -y
```

---

## Étape 4 : Installation de Coturn

### 4.1 Installer coturn
```bash
apt install coturn -y
```

### 4.2 Activer coturn comme service
```bash
echo "TURNSERVER_ENABLED=1" > /etc/default/coturn
```

---

## Étape 5 : Configuration SSL avec Let's Encrypt

### 5.1 Installer Certbot
```bash
apt install certbot -y
```

### 5.2 Obtenir le certificat SSL
```bash
certbot certonly --standalone -d turn.diasponiger.com --agree-tos -m votre@email.com
```

### 5.3 Créer le script de renouvellement automatique
```bash
cat > /etc/letsencrypt/renewal-hooks/deploy/coturn.sh << 'EOF'
#!/bin/bash
cp /etc/letsencrypt/live/turn.diasponiger.com/fullchain.pem /etc/coturn/cert.pem
cp /etc/letsencrypt/live/turn.diasponiger.com/privkey.pem /etc/coturn/key.pem
chown turnserver:turnserver /etc/coturn/*.pem
chmod 600 /etc/coturn/*.pem
systemctl restart coturn
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/coturn.sh
```

### 5.4 Copier les certificats
```bash
mkdir -p /etc/coturn
cp /etc/letsencrypt/live/turn.diasponiger.com/fullchain.pem /etc/coturn/cert.pem
cp /etc/letsencrypt/live/turn.diasponiger.com/privkey.pem /etc/coturn/key.pem
chown turnserver:turnserver /etc/coturn/*.pem
chmod 600 /etc/coturn/*.pem
```

---

## Étape 6 : Configuration de Coturn

### 6.1 Sauvegarder la configuration originale
```bash
mv /etc/turnserver.conf /etc/turnserver.conf.backup
```

### 6.2 Créer la nouvelle configuration
```bash
cat > /etc/turnserver.conf << 'EOF'
# Configuration réseau
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
relay-ip=VOTRE_IP_VPS
external-ip=VOTRE_IP_VPS

# Domaine et realm
realm=turn.diasponiger.com
server-name=turn.diasponiger.com

# Certificats TLS
cert=/etc/coturn/cert.pem
pkey=/etc/coturn/key.pem

# Authentification
lt-cred-mech
user=diasponiger:VotreMotDePasseSecurise123!

# Paramètres de sécurité
fingerprint
no-tlsv1
no-tlsv1_1
no-stdout-log
syslog

# Limites de ports pour le relay
min-port=49152
max-port=65535

# Logging
log-file=/var/log/coturn/turnserver.log
simple-log
EOF
```

> [!IMPORTANT]
> **Remplacez** :
> - `VOTRE_IP_VPS` par l'adresse IP de votre VPS
> - `VotreMotDePasseSecurise123!` par un mot de passe fort

### 6.3 Créer le dossier de logs
```bash
mkdir -p /var/log/coturn
chown turnserver:turnserver /var/log/coturn
```

---

## Étape 7 : Configuration du Firewall

### 7.1 Ouvrir les ports nécessaires
```bash
ufw allow 22/tcp       # SSH
ufw allow 3478/tcp     # TURN TCP
ufw allow 3478/udp     # TURN UDP
ufw allow 5349/tcp     # TURNS (TLS)
ufw allow 5349/udp     # TURNS (TLS)
ufw allow 49152:65535/udp  # Ports relay
ufw enable
```

---

## Étape 8 : Démarrer Coturn

### 8.1 Démarrer le service
```bash
systemctl enable coturn
systemctl start coturn
systemctl status coturn
```

### 8.2 Vérifier les logs
```bash
tail -f /var/log/coturn/turnserver.log
```

---

## Étape 9 : Test du serveur

### 9.1 Test en ligne
Utilisez https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/

Configuration de test :
```
STUN: stun:turn.diasponiger.com:3478
TURN: turn:turn.diasponiger.com:3478
TURNS: turns:turn.diasponiger.com:5349
Username: diasponiger
Password: VotreMotDePasseSecurise123!
```

---

## Étape 10 : Intégration Flutter

### Fichier à modifier
[webrtc_service.dart](file:///c:/Users/danko/StudioProjects/projet_perso/diaspo_niger/lib/core/services/webrtc_service.dart)

### Configuration actuelle (à remplacer)
```dart
// Lignes 9-33 dans webrtc_service.dart
class IceServerConfig {
  static const List<Map<String, dynamic>> iceServers = [
    {
      'urls': [
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
      ]
    },
    // TURN server for NAT traversal on restrictive networks
    // TODO: Replace with your own TURN server credentials for production
    {
      'urls': 'turn:openrelay.metered.ca:80',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    ...
  ];
}
```

### Nouvelle configuration (votre serveur coturn)
```dart
class IceServerConfig {
  static const List<Map<String, dynamic>> iceServers = [
    // STUN servers (gratuits, pour découverte d'IP)
    {
      'urls': [
        'stun:turn.diasponiger.com:3478',
        'stun:stun1.l.google.com:19302',
      ]
    },
    // Votre serveur TURN self-hosted
    {
      'urls': 'turn:turn.diasponiger.com:3478',
      'username': 'diasponiger',
      'credential': 'VotreMotDePasseSecurise123!',
    },
    // TURNS (TLS) pour réseaux restrictifs
    {
      'urls': 'turns:turn.diasponiger.com:5349',
      'username': 'diasponiger',
      'credential': 'VotreMotDePasseSecurise123!',
    },
    // TCP fallback pour pare-feux stricts
    {
      'urls': 'turn:turn.diasponiger.com:3478?transport=tcp',
      'username': 'diasponiger',
      'credential': 'VotreMotDePasseSecurise123!',
    },
  ];
}
```

> [!IMPORTANT]
> Je mettrai à jour ce fichier pour vous une fois coturn configuré.

---

## Résumé des informations

| Élément | Valeur |
|---------|--------|
| **STUN URL** | `stun:turn.diasponiger.com:3478` |
| **TURN URL** | `turn:turn.diasponiger.com:3478` |
| **TURNS URL (TLS)** | `turns:turn.diasponiger.com:5349` |
| **Username** | `diasponiger` |
| **Password** | `VotreMotDePasseSecurise123!` |

---

## Maintenance

### Vérifier le statut
```bash
systemctl status coturn
```

### Redémarrer coturn
```bash
systemctl restart coturn
```

### Voir les logs
```bash
tail -100 /var/log/coturn/turnserver.log
```

### Renouveler le certificat SSL (automatique, mais si nécessaire)
```bash
certbot renew
```
