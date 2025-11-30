#!/bin/bash
# user_data.sh.tpl

set -euo pipefail

echo "Waiting for cloud-init..."
/usr/bin/cloud-init status --wait > /dev/null

export DEBIAN_FRONTEND=noninteractive
apt-get update > /dev/null
apt-get install -y python3-pip git iptables-persistent --no-install-recommends > /dev/null
python3 -m pip install --quiet --no-cache-dir ansible > /dev/null

cat > /home/ubuntu/playbook.yml <<'EOF'
---
- name: LAMP + PostgreSQL 16 for Oracle Cloud Always Free
  hosts: localhost
  become: yes
  vars:
    ansible_ssh_pipelining: true

  tasks:
    - name: Wait for apt locks and cloud-init
      shell: |
        while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock* 2>/dev/null; do sleep 5; done
        cloud-init status --wait || true
      changed_when: false

    - name: Update cache
      apt:
        update_cache: yes

    - name: Add PostgreSQL key & repo
      block:
        - get_url:
            url: https://www.postgresql.org/media/keys/ACCC4CF8.asc
            dest: /etc/apt/trusted.gpg.d/pgdg.asc
            mode: '0644'
        - apt_repository:
            repo: "deb https://apt.postgresql.org/pub/repos/apt jammy-pgdg main"
            state: present
            filename: pgdg

    - name: Install packages
      apt:
        name:
          - apache2
          - php
          - libapache2-mod-php
          - php-pgsql
          - postgresql-16
          - git
          - unattended-upgrades
          - iptables-persistent
        state: present

    - name: Remove Oracle’s REJECT rule that blocks port 80
      iptables:
        chain: INPUT
        jump: REJECT
        reject_with: icmp-host-prohibited
        state: absent
      ignore_errors: yes

    - name: Save iptables rules
      command: netfilter-persistent save
      when: ansible_os_family == "Debian"

    - name: Harden PHP
      lineinfile:
        path: /etc/php/*/apache2/php.ini
        regexp: "{{ item.regexp }}"
        line: "{{ item.line }}"
      loop:
        - { regexp: '^;?disable_functions', line: 'disable_functions = exec,passthru,shell_exec,system,proc_open,popen' }
        - { regexp: '^;?expose_php', line: 'expose_php = Off' }
      notify: restart apache

    - name: Apache security configs
      copy:
        dest: "{{ item.dest }}"
        content: "{{ item.content }}"
        mode: '0644'
      loop:
        - { dest: /etc/apache2/conf-enabled/security.conf, content: |
            ServerTokens Prod
            ServerSignature Off
            TraceEnable Off }
        - { dest: /etc/apache2/conf-enabled/headers.conf, content: |
            Header always set X-Content-Type-Options "nosniff"
            Header always set X-Frame-Options "DENY" }
      notify: restart apache

    - name: Listen only on port 80
      replace:
        path: /etc/apache2/ports.conf
        regexp: '^Listen.*'
        replace: 'Listen 80'
      notify: restart apache

    - name: Enable modules and default site
      shell: a2enmod rewrite headers && a2ensite 000-default || true
      notify: restart apache

    - name: Unattended upgrades
      copy:
        dest: "{{ item.d }}"
        content: "{{ item.c }}"
        mode: '0644'
      loop:
        - { d: /etc/apt/apt.conf.d/50unattended-upgrades, c: |
            Unattended-Upgrade::Allowed-Origins {
              "Ubuntu:jammy";
              "Ubuntu:jammy-security";
              "Ubuntu:jammy-updates";
            };
            Unattended-Upgrade::Automatic-Reboot "true"; }
        - { d: /etc/apt/apt.conf.d/20auto-upgrades, c: |
            APT::Periodic::Update-Package-Lists "1";
            APT::Periodic::Unattended-Upgrade "1"; }

    - name: Deploy index.php
      copy:
        dest: /var/www/html/index.php
        owner: www-data
        group: www-data
        mode: '0644'
        content: |
          <!DOCTYPE html><html><head><meta charset="utf-8"><title>Title Page for Web Hosting!</title>
          <style>body{font-family:system-ui,sans-serif;text-align:center;padding:5rem;background:#0f172a;color:#e2e8f0;}</style>
          </head><body><h1>Hello </h1>
          <p>LAMP + PostgreSQL 16 • Oracle Cloud</p>
          <p>IP: <?php echo $_SERVER['SERVER_ADDR']; ?> • PHP <?php echo phpversion(); ?></p>
          </body></html>

    - name: Final restart
      systemd:
        name: apache2
        state: restarted

  handlers:
    - name: restart apache
      systemd:
        name: apache2
        state: restarted
EOF

echo "Running playbook..."
cd /home/ubuntu
sudo -u ubuntu ansible-playbook playbook.yml -c local

echo "Configured – your site is live at http://$(curl -s ifconfig.me || hostname -I | awk '{print $1}')"
