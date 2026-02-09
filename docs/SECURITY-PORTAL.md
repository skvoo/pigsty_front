# Защита портала Pigsty (http://104.223.25.234/)

**Сервер:** 104.223.25.234  
**Цель:** ограничить доступ к веб-интерфейсу (Dashboard, Grafana, метрики, логи) и снизить риски при доступе из интернета.

---

## 1. Текущее состояние

| Мера | Статус |
|------|--------|
| **Basic Auth (Nginx)** | ✅ Включён: пользователь `admin`, пароль задан в `pigsty.yml` → `nginx_users` |
| **HTTPS (SSL)** | ❌ Не включён — пароль Basic Auth передаётся по HTTP |
| **Firewall (UFW)** | ❌ Не активен — все порты доступны с любого IP |
| **SSH root** | ⚠️ Разрешён (`PermitRootLogin yes`) |

**Итог:** портал уже прикрыт логином/паролем, но без HTTPS пароль можно перехватить. Ограничения по IP нет.

---

## 2. Рекомендуемые меры (по приоритету)

### 2.1 Включить HTTPS для Nginx (обязательно при доступе из интернета)

Без HTTPS пароль Basic Auth передаётся в открытом виде. Pigsty умеет использовать самоподписанный сертификат (или Certbot для Let's Encrypt).

**В `pigsty.yml` в секции `vars` добавить или раскомментировать:**

```yaml
# SSL для портала (параметры INFRA / Nginx)
nginx_sslmode: enable    # enable — HTTPS на 443, HTTP на 80; enforce — редирект HTTP→HTTPS
# nginx_sslmode: enforce  # использовать enforce, чтобы принудительно уходить на HTTPS
```

После правки применить конфиг Nginx на сервере:

```bash
# С хоста, откуда крутится Ansible (или с сервера 104.223.25.234)
cd ~/pigsty
ansible-playbook -i inventory/pigsty infra.yml -l infra -t nginx
```

После этого портал будет доступен по **https://104.223.25.234/** (браузер покажет предупреждение о самоподписанном сертификате — для админ-доступа это допустимо).

**Если есть домен и нужен валидный сертификат:** см. [Pigsty — Nginx Parameters](https://pigsty.io/docs/infra/param/#nginx) (certbot_sign, certbot_email, запись в infra_portal с certbot).

---

### 2.2 Включить UFW и ограничить порты

Оставить снаружи только нужные порты; 5432 и 6432 — только с доверенных IP (админ, фронтенды).

**На сервере 104.223.25.234:**

```bash
# Разрешить SSH, HTTP, HTTPS
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# PgBouncer (6432) — только с IP фронтендов (пример: замените на свои подсети)
# sudo ufw allow from <IP_ФРОНТЕНДА> to any port 6432

# PostgreSQL (5432) — только с админских IP или закрыть снаружи
# sudo ufw allow from <ВАШ_IP> to any port 5432
# Либо не открывать 5432 вовсе, если заходите только по SSH и туннелю

# Включить фаервол (проверить, что SSH не отвалится: лучше сначала allow 22)
sudo ufw enable
sudo ufw status
```

Перед `ufw enable` убедитесь, что порт 22 разрешён и вход под `st` по SSH работает.

---

### 2.3 Отключить вход по SSH под root

После проверки входа под обычным пользователем (`st`):

```bash
# В /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl reload sshd
```

---

### 2.4 Надёжный пароль Basic Auth и сохранение конфига

- Пароль в `nginx_users` должен быть сложным; не хранить `pigsty.yml` в публичном репозитории (уже учтено в плане).
- Файл `files/pki/ca/ca.key` на ноде с Pigsty — закрыть правами и бэкапить (см. [Security Tips](https://pigsty.io/docs/setup/security/)).

---

## 3. Чеклист

- [ ] Включить HTTPS: в `pigsty.yml` задать `nginx_sslmode: enable` (или `enforce`), применить плейбук `infra.yml -t nginx`.
- [ ] Проверить доступ по https://104.223.25.234/ с Basic Auth.
- [ ] Включить UFW: разрешить 22, 80, 443; при необходимости 6432/5432 только с доверенных IP.
- [ ] В `sshd_config`: `PermitRootLogin no`, перезапустить sshd.
- [ ] Убедиться, что пароль в `nginx_users` сложный и конфиг не светится в открытом доступе.

После этого портал будет защищён: HTTPS + Basic Auth + фаервол + отключённый root SSH.
