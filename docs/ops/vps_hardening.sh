#!/usr/bin/env bash
#
# Durcissement VPS Coturn - diaspo_niger
# À exécuter EN ROOT sur un VPS FRAÎCHEMENT RÉINSTALLÉ (Ubuntu 22.04/24.04).
#
# Ordre d'usage :
#   1. Réinstaller l'OS depuis hPanel Hostinger.
#   2. Depuis TA machine :  ssh-copy-id -i ~/.ssh/id_ed25519.pub root@72.62.212.223
#   3. Vérifier que "ssh root@72.62.212.223" fonctionne SANS mot de passe.
#   4. Copier ce script sur le serveur et lancer :  bash vps_hardening.sh
#
# Le script REFUSE de couper l'auth par mot de passe si aucune clé SSH n'est
# installée pour root (protection anti-lock-out).
#
set -euo pipefail

echo "==> [0/8] Vérifications préalables"
if [[ $EUID -ne 0 ]]; then echo "Lance-moi en root."; exit 1; fi

ROOT_KEYS="/root/.ssh/authorized_keys"
if [[ ! -s "$ROOT_KEYS" ]]; then
  echo "!! ERREUR : aucune clé SSH dans $ROOT_KEYS."
  echo "   Fais d'abord 'ssh-copy-id root@<ip>' depuis ta machine, puis relance."
  exit 1
fi
echo "   Clé SSH root présente. OK."

echo "==> [1/8] Mise à jour du système"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get upgrade -y

echo "==> [2/8] Installation ufw + fail2ban"
apt-get install -y ufw fail2ban

echo "==> [3/8] Firewall ufw (deny by default, ouvre uniquement le nécessaire)"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp                 # SSH
ufw allow 80/tcp                 # HTTP (certbot / nginx)
ufw allow 443/tcp                # HTTPS
ufw allow 3478/tcp               # TURN
ufw allow 3478/udp               # TURN
ufw allow 5349/tcp               # TURNS (TLS)
ufw allow 5349/udp               # TURNS (TLS)
ufw allow 49152:65535/udp        # plage relais coturn (min-port/max-port)
ufw --force enable
ufw status verbose

echo "==> [4/8] SSH : clé uniquement, pas de root par mot de passe"
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
MaxAuthTries 3
X11Forwarding no
EOF
# Neutralise le fichier cloud-init qui réactive les mots de passe
if [[ -f /etc/ssh/sshd_config.d/50-cloud-init.conf ]]; then
  sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf
fi
sshd -t && systemctl restart ssh
echo "   SSH durci. (Garde CETTE session ouverte et teste une NOUVELLE connexion avant de fermer !)"

echo "==> [5/8] Retirer le sudo NOPASSWD du compte ubuntu"
# Le NOPASSWD:ALL est le combo qui a permis l'escalade root du malware.
find /etc/sudoers.d -type f -exec grep -l 'NOPASSWD' {} \; | while read -r f; do
  echo "   -> nettoyage $f"
  sed -i '/NOPASSWD/d' "$f"
done
echo "   (ubuntu devra désormais taper un mot de passe pour sudo)"

echo "==> [6/8] fail2ban sur SSH"
cat > /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled  = true
port     = 22
maxretry = 4
findtime = 10m
bantime  = 1h
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

echo "==> [7/8] Coturn : passer en use-auth-secret (corrige le relais + rote le secret)"
cat <<'EOF'
   !! IMPORTANT — le relais TURN est actuellement CASSÉ.
      functions/index.js (getTurnCredentials) génère des credentials éphémères
      HMAC-SHA1 (TURN REST API), mais /etc/turnserver.conf utilise un user
      statique (lt-cred-mech + user=diasponiger:...) => coturn REJETTE les
      credentials de l'app. Les appels ne passent que via P2P/STUN direct et
      échouent sur NAT symétrique / réseaux restrictifs.

   >> LE FIX (côté serveur) :
        cp /etc/turnserver.conf /etc/turnserver.conf.bak-$(date +%F)
        SECRET=$(openssl rand -base64 32)
        sed -i '/^user=diasponiger/d; /^static-auth-secret=/d; /^use-auth-secret/d' /etc/turnserver.conf
        printf 'use-auth-secret\nstatic-auth-secret=%s\n' "$SECRET" >> /etc/turnserver.conf
        systemctl restart coturn && systemctl is-active coturn
        # Affiche le secret pour le copier dans Firebase :
        grep '^static-auth-secret=' /etc/turnserver.conf

   >> PUIS (côté Firebase) — le secret DOIT être identique :
        # dans functions/.env :  TURN_SECRET=<le meme secret>
        firebase deploy --only functions:getTurnCredentials

      Ça supprime le user statique compromis ([ANCIEN-SECRET-ROTE-2026-07-16]) ET
      fait enfin fonctionner le relais.

   >> Durcissement additionnel dans /etc/turnserver.conf :
        no-cli
        no-loopback-peers
        denied-peer-ip=0.0.0.0-0.255.255.255
        denied-peer-ip=10.0.0.0-10.255.255.255
        denied-peer-ip=172.16.0.0-172.31.255.255
        denied-peer-ip=192.168.0.0-192.168.255.255
        denied-peer-ip=169.254.0.0-169.254.255.255
      -> empêche que ton relais TURN serve à scanner ton réseau interne.
EOF

echo "==> [8/8] Terminé."
echo "    ⚠️  AVANT DE FERMER CETTE SESSION : ouvre un NOUVEAU terminal et vérifie"
echo "        que 'ssh root@72.62.212.223' fonctionne (par clé). Sinon tu seras bloqué."
