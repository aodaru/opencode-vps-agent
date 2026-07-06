# ============================================================
# Dockerfile: OpenCode VPS Agent
# Ubuntu 24.04 + OpenCode (binario estatico) + Cloudflare Tunnel
# ============================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# ============================================================
# 1. Dependencias base y seguridad
# ============================================================
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    git \
    tmux \
    ufw \
    fail2ban \
    ca-certificates \
    supervisor \
    xdg-utils \
    openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd

# ============================================================
# 2. OpenCode (binario estatico, sin Node.js)
# ============================================================
RUN curl -fsSL https://opencode.ai/install | bash \
    && cp /root/.opencode/bin/opencode /usr/local/bin/opencode \
    && chmod +x /usr/local/bin/opencode

# ============================================================
# 3. cloudflared (tunel Cloudflare)
# ============================================================
RUN curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb \
    -o /tmp/cloudflared.deb \
    && dpkg -i /tmp/cloudflared.deb \
    && rm /tmp/cloudflared.deb

# ============================================================
# 4. GitHub CLI (gh)
# ============================================================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install gh -y

# ============================================================
# 5. Usuarios: devadmin (sudo) + cloud (agente, sin sudo)
# ============================================================
RUN useradd -m -s /bin/bash devadmin \
    && echo "devadmin:changeme" | chpasswd \
    && adduser devadmin sudo

RUN useradd -m -s /bin/bash cloud \
    && echo "cloud:changeme" | chpasswd

# ============================================================
# 5b. Configurar SSH (permitir auth por contraseña)
# ============================================================
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && echo "AllowUsers devadmin cloud" >> /etc/ssh/sshd_config

# ============================================================
# 6. Workspace del agente
# ============================================================
RUN mkdir -p /home/cloud/proyectos \
    && mkdir -p /home/cloud/.config/opencode \
    && mkdir -p /home/cloud/.cloudflared \
    && mkdir -p /home/cloud/.local/share/opencode \
    && mkdir -p /home/cloud/.ssh \
    && mkdir -p /home/devadmin/.ssh \
    && chown -R cloud:cloud /home/cloud/ \
    && chown -R devadmin:devadmin /home/devadmin/

# Copiar configuraciones pre-creadas
COPY config/opencode.json /home/cloud/.config/opencode/opencode.json
COPY config/cloudflared.yml /home/cloud/.cloudflared/config.yml
COPY scripts/fix-ownership.sh /usr/local/bin/fix-ownership.sh
COPY supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY supervisor/opencode-web.conf /etc/supervisor/conf.d/opencode-web.conf
COPY supervisor/sshd.conf /etc/supervisor/conf.d/sshd.conf
COPY supervisor/fix-ownership.conf /etc/supervisor/conf.d/fix-ownership.conf

RUN chmod +x /usr/local/bin/fix-ownership.sh \
    && chown -R cloud:cloud /home/cloud/.config/opencode/opencode.json \
    && chown -R cloud:cloud /home/cloud/.cloudflared/config.yml

# ============================================================
# 7. Setup script
# ============================================================
COPY setup.sh /usr/local/bin/setup-opencode.sh
RUN chmod +x /usr/local/bin/setup-opencode.sh

WORKDIR /home/cloud/proyectos
EXPOSE 22

# Supervisor gestiona opencode-web + cloudflared
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
