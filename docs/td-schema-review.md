# Проверка схемы БД TD (по Context7 / PostgreSQL 16 docs)

Проверка таблиц `public.users` и `public.tickets` по рекомендациям [PostgreSQL 16](https://www.postgresql.org/docs/16/ddl-constraints).

---

## Что в порядке

| Аспект | Статус |
|--------|--------|
| **NOT NULL** на обязательных полях | ✅ id, email, password_hash, role, created_at в users; id, user_id, file_url, created_at в tickets |
| **Индекс на referencing column (FK)** | ✅ Документация: *"it is often a good idea to index the referencing columns too"* — есть `tickets_user_id_idx` на `tickets(user_id)` |
| **UNIQUE на email** | ✅ Ограничение + индекс `users_email_key` для поиска по email |
| **Именованный FK** | ✅ REFERENCES с ON DELETE CASCADE; при необходимости можно задать имя вручную |
| **Длина password_hash** | ✅ varchar(255) достаточно (bcrypt ~60 символов) |

---

## Исправлено по рекомендациям

### 1. CHECK для колонки `role`

**Проблема:** Колонка `role varchar(20) DEFAULT 'user'` без ограничения по множеству значений — в БД можно было записать любое значение (опечатка, лишняя роль).

**Рекомендация PostgreSQL:** CHECK-ограничение для проверки значения; именованный constraint — для понятных сообщений об ошибках ([ddl-constraints](https://www.postgresql.org/docs/16/ddl-constraints)).

**Сделано:** В схему добавлен именованный CHECK:

```sql
CONSTRAINT users_role_check CHECK (role IN ('user', 'admin'))
```

Миграция для уже развёрнутой БД: `sql/td_users_add_role_check.sql`.

---

## Структура после проверки

- **users:** id (PK), email (UNIQUE NOT NULL), password_hash (NOT NULL), role (NOT NULL DEFAULT 'user' **CHECK (role IN ('user', 'admin'))**), created_at.
- **tickets:** без изменений; индексы и FK соответствуют рекомендациям.

При добавлении новых ролей нужно один раз обновить constraint:  
`ALTER TABLE public.users DROP CONSTRAINT users_role_check; ALTER TABLE public.users ADD CONSTRAINT users_role_check CHECK (role IN ('user', 'admin', 'moderator'));` (и т.д.).
