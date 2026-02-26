# Override: Patroni OLTP template (clonefrom fix)

This directory contains a **patched** Pigsty template `oltp.yml` for Patroni.

## Change

- **Original (Pigsty):** `tags.clonefrom: true` (hardcoded) → every node tries to start as replica, which breaks single-node primary.
- **Patched:** `tags.clonefrom: {{ (pg_role | default('primary')) != 'primary' }}` → `false` for primary, `true` for replica/offline.

See [docs/Reports/REPORT-PATRONI-MISCONFIG-2026-02.md](../../../docs/Reports/REPORT-PATRONI-MISCONFIG-2026-02.md).

## How to use

### Option A: Copy to Pigsty on the server

On the server where Pigsty is installed (e.g. `~/pigsty`):

```bash
# Backup original
cp ~/pigsty/roles/pgsql/templates/oltp.yml ~/pigsty/roles/pgsql/templates/oltp.yml.bak

# Copy patched template from this repo (e.g. from your workstation)
scp roles/pgsql/templates/oltp.yml st@104.223.25.234:~/pigsty/roles/pgsql/templates/oltp.yml
```

Then run the PGSQL playbook as usual; the generated Patroni config will have `clonefrom: false` for primary nodes.

### Option B: Run Ansible with this repo’s roles first

If you run playbooks from this repo and want this role to override Pigsty’s:

```bash
export ANSIBLE_ROLES_PATH="$(pwd)/roles:~/pigsty/roles"
./pgsql.yml -l pg-meta   # or use the playbook from ~/pigsty with -e "roles_path=..."
```

Ensure this repo’s `roles` directory is before Pigsty’s in `ANSIBLE_ROLES_PATH` so `roles/pgsql/templates/oltp.yml` is used.

### Option C: Manual patch on the server

On the server, in `~/pigsty/roles/pgsql/templates/oltp.yml` find the line:

```yaml
 clonefrom: true
```

Replace it with:

```yaml
 clonefrom: {{ (pg_role | default('primary')) != 'primary' }}
```

Then re-run the PGSQL playbook. Alternatively, fix the already-generated config: edit `/etc/patroni/patroni.yml` and set `clonefrom: false` for the primary node, then restart Patroni.

## After deploying

Check that the primary node gets `clonefrom: false`:

```bash
sudo grep clonefrom /etc/patroni/patroni.yml
# Expect: clonefrom: false  (for single-node primary)

sudo -u postgres patronictl -c /etc/patroni/patroni.yml list
# Expect: Role Leader, State running
```
