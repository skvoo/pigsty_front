# Интеграция Vercel с БД TD (Pigsty)

Инструкция по подключению фронтенда на Vercel к базе **TD** на сервере 104.223.25.234.

---

## Что создано на стороне БД

В конфиге Pigsty (`pigsty.yml`) добавлено:

- **База данных:** `td` (comment: TD app, Vercel integration).
- **Пользователь:** `tdadmin`, роль админа БД (`dbrole_admin`), доступ через PgBouncer.
- **Пароль:** `TdAdmin7xKp2mNqR` (хранить в секретах, в репозиторий не коммитить).
- **Доступ:** для пользователя `tdadmin` и базы `td` разрешены подключения с любых IP (addr: world) по паролю — подходит для serverless на Vercel.

---

## Применение на сервере (один раз)

Конфиг нужно применить на 104.223.25.234. Если `pigsty.yml` уже обновлён в репозитории:

1. Скопировать актуальный `pigsty.yml` на сервер в каталог Pigsty, например:
   ```bash
   scp pigsty.yml st@104.223.25.234:~/pigsty/pigsty.yml
   ```

2. На сервере выполнить (создание пользователя, базы, применение HBA и перезагрузка PgBouncer):
   ```bash
   ssh st@104.223.25.234
   cd ~/pigsty
   ansible-playbook -l pg-meta pgsql-user.yml   # создать пользователя tdadmin
   ansible-playbook -l pg-meta pgsql-db.yml     # создать базу td
   ansible-playbook -l pg-meta -e pg_reload=true -t pgbouncer_hba,pgbouncer_reload pgsql.yml
   ```

3. Проверить подключение с любой машины:
   ```bash
   psql "postgresql://tdadmin:TdAdmin7xKp2mNqR@104.223.25.234:6432/td" -c "SELECT current_database();"
   ```

---

## Настройка Vercel

**Зачем:** приложение на Vercel подключается к БД только с бэкенда (API routes / serverless), не из браузера. Строку подключения задаём в переменных окружения.

**1. Переменная окружения**

В Vercel: Project → **Settings** → **Environment Variables** добавить:

| Name           | Value                                                                 | Environments   |
|----------------|-----------------------------------------------------------------------|----------------|
| `DATABASE_URL` | `postgresql://tdadmin:TdAdmin7xKp2mNqR@104.223.25.234:6432/td`       | Production (и при необходимости Preview) |

Значение вставлять без пробелов. Пароль не коммитить в репозиторий — только в Vercel (или в .env локально, .env в .gitignore).

**2. Порт и хост**

- Хост: `104.223.25.234`
- Порт: `6432` (PgBouncer). Прямой порт PostgreSQL (5432) для приложений не использовать.

**3. Использование в коде (Next.js)**

В API routes (например `app/api/.../route.ts` или `pages/api/...`) подключаться через `process.env.DATABASE_URL`:

```ts
import { Pool } from 'pg';

const pool = process.env.DATABASE_URL
  ? new Pool({ connectionString: process.env.DATABASE_URL })
  : null;

export async function GET() {
  if (!pool) {
    return Response.json({ error: 'DATABASE_URL not set' }, { status: 503 });
  }
  const { rows } = await pool.query('SELECT current_database()');
  return Response.json(rows);
}
```

Зависимость: в проекте должен быть установлен пакет `pg` (в проекте бэкенда/API, не только во фронте).

**4. Редеплой**

После добавления или изменения переменных в Vercel сделать **Redeploy** нужного окружения (Production/Preview), чтобы serverless-функции получили новое значение `DATABASE_URL`.

---

## Кратко

- База: **td**, пользователь: **tdadmin**, пароль: **TdAdmin7xKp2mNqR**, хост: **104.223.25.234**, порт: **6432**.
- В Vercel задать **DATABASE_URL** = `postgresql://tdadmin:TdAdmin7xKp2mNqR@104.223.25.234:6432/td`.
- В коде использовать `process.env.DATABASE_URL` только на сервере (API routes), ставить `pg` в backend-зависимостях. После смены переменных — редеплой.
