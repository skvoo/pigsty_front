# Вход по ключу на 172.245.64.199 (n8n)

Чтобы Pigsty (104.223.25.234) мог подключаться к n8n без пароля, на сервере n8n в `~/.ssh/authorized_keys` пользователя **st** должен быть добавлен ключ с Pigsty.

## Способ 1: одна команда с вашей машины (введите пароль когда попросит)

Откройте **терминал в Cursor** (Terminal → New Terminal) и выполните **по очереди** (две команды):

```powershell
cd c:\Users\sk\.cursor\projects\pigsty
```

```powershell
Get-Content pigsty_pubkey.txt | ssh -o StrictHostKeyChecking=accept-new st@172.245.64.199 "mkdir -p ~/.ssh; chmod 700 ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys; echo DONE"
```

Либо одной строкой с точкой с запятой (без переноса между командами):

```powershell
cd c:\Users\sk\.cursor\projects\pigsty; Get-Content pigsty_pubkey.txt | ssh -o StrictHostKeyChecking=accept-new st@172.245.64.199 "mkdir -p ~/.ssh; chmod 700 ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys; echo DONE"
```

Когда `ssh` запросит пароль — введите пароль пользователя **st** на 172.245.64.199.

## Способ 2: зайти по паролю и вставить ключ вручную

1. В терминале: `ssh st@172.245.64.199` и введите пароль.
2. После входа на сервер выполните (одной строкой):

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0uoXtcFb6GHGJPpX8W1ZkyACgIDhYnWNmo1Qdpr34DzWVEYM4zwz6O62vegRwzJWvFOyawlzuFhNueiA9wX3jrA+tBI+8EBw427ghLzXqXgnITirZKdSSZooLrEyz1VSz4r029qItRH8cf6b0jbkWByW2LBY9SpUobeHy3lAFvWPwJeIBfKSIdXpwJJZDmVt6OdHi9DgJXMCiHiMqI2y6dGJpxCO6psIQ1hhBBbP0u8SZNdLm1QCTfSMQ1NVvONg8yndb6O8augwpMyivMLp4b7YUU8VbY1q5nMVk6Q+boReCCCYmdv7X1bpLAhHBJsYTvobPIxhUSJ+goHXV+F6j st@racknerd-cd14e40' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo DONE
```

3. Выйдите: `exit`.

## Проверка

С сервера Pigsty (или после настройки можно попросить проверить):

```bash
ssh st@172.245.64.199 "echo OK && hostname"
```

Должно вывести `OK` и имя хоста без запроса пароля.

## Дальше

После успешной проверки на 104.223.25.234 выполните:

```bash
cd ~/pigsty && ansible 172.245.64.199 -m ping
./node.yml -l 172.245.64.199 -t node_exporter,node_register
```

Тогда n8n появится в мониторинге Grafana.
