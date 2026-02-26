# Подключение pgAdmin к Supabase

К базам Supabase (PostgreSQL) можно подключаться через pgAdmin так же, как к любому другому Postgres-серверу.

---

## Параметры из Dashboard

В Supabase: **Connect** → выберите **Session pooler** (для IPv4) или Direct connection. В блоке **View parameters** будут:

- **Host** — например `aws-1-ap-south-1.pooler.supabase.com` (Session pooler) или `db.REF.supabase.co` (Direct)
- **Port** — `5432`
- **Database** — `postgres`
- **User** — `postgres.REF` (например `postgres.czhonxtlovawwjfbxgbx`)
- **Password** — пароль БД (Database Settings → Reset database password)

---

## Настройка в pgAdmin

1. Правый клик по **Servers** → **Register** → **Server**.
2. Вкладка **General:** имя, например `Supabase GD-lounge`.
3. Вкладка **Connection:**
   - **Host name / address:** хост из Connect (pooler или direct).
   - **Port:** `5432`.
   - **Maintenance database:** `postgres`.
   - **Username:** `postgres.REF` (полностью, с точкой).
   - **Password:** пароль БД (можно сохранить в pgAdmin).
4. **Save** — подключение появится в дереве, можно открывать схемы и выполнять SQL.

---

## Замечания

- **Session pooler** нужен, если у вас только IPv4 (например домашний интернет без IPv6). Direct connection по умолчанию только IPv6.
- В pgAdmin при первом подключении может спросить сохранение пароля — по желанию.
- Для каждого проекта Supabase (GD-lounge, imperial и т.д.) заводите отдельный сервер в pgAdmin с своими host/user/password.

См. также: [INSTALL-PGADMIN.md](./INSTALL-PGADMIN.md) — установка pgAdmin через Pigsty и подключение к БД на Pigsty.
