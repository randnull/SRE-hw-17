# Видео-демо
```
Google-диск: https://drive.google.com/file/d/1PYOG8xsIVtGqEOF63aC0G0yoh9yX0qUp/view?usp=sharing
Yandex-диск: https://disk.yandex.ru/d/JTRlp_rzJ1PkZw
```
# Подготовка

# Multipass
Для создания виртуальных машин будет использовать утилиту Multipass.

# Особенности ssh для Multipass

После создании виртуальной машины, подключиться по ssh к ней не получилось (permission denied).
Для того, чтобы получить возможность подключаться по ssh необходим файл настроек vm:
```
cloud-init.yaml
```
В нем опишем логин и ssh публичный ключ машины, с которой будет управлять нашими виртуальными машинами.

Для генерации ключа воспользуемся  
```
ssh-keygen -t rsa -b 4096 -f ~/.ssh/multipass-ssh-key
```
После чего скопируем multipass-ssh-key.pub ключ из ssh/multipass-ssh-key и поместим его в наш файл cloud-init

Также воспользуемся ssh-add в качестве временного решения для ssh:
```
ssh-add ~/.ssh/multipass-ssh-key
```
После чего создадим машину использую файл cloud-init:

Для test:
```
multipass launch -n testvm --cloud-init cloud-init.yaml
```
Для prod:
```
multipass launch -n prodvm --cloud-init cloud-init.yaml
```
Получаем две рабочии машины:

![Иллюстрация к проекту](https://github.com/randnull/SRE-hw-17/blob/main/images/vm_runs.png)

# Ansible

В inventory должно быть определено два окружения: testing и production

Определим в папке inventory 2 окружения, в которые поместим адреса хостов и переменную env (production/testing).
(пароль использовать не обязательно, поскольку мы скопировали наш ssh ключ на машины)

Опишем плейбук для установки (nginx_install.yml), в который поместим роль install_nginx

Для того, чтобы при переходе на URL "/" отображалась HTML страница по шаблону "Hello <Ваше имя>! Welcome to <окружение>."
заменим index.html на наш, а также подключим его через default.conf (папка install_nginx/templates).

В качестве defaults (install_nginx/defaults) определим наше имя.

Установим nginx используя apt, заменим шаблоны и сделаем handler на перезапуск на изменения конфигураций,
чтобы при каждом изменении nginx выполнялся restart. (install_nginx/tasks/main.yml)

# Аутентификация и секреты

Для того, чтобы воспользоваться HTTP Basic аутентификацией, в install_nginx/tasks/secure.yml установим python, passlib через apt и добавим вызов htpasswd.

Чтобы вызвать install_nginx/tasks/secure.yml из install_nginx/tasks/main.yml используем include_tasks:

```
- name: include secure task
  include_tasks: secure.yml
```

Однако хранить пароли/логины в открытом виде плохо, поэтому используем ansible-vault для хранения.

Наилучшим образом подойдет способ через encrypt_string, который отдаст нам зашифрованную строку (пример в vars/...)

```
ansible-vault encrypt_string --vault-id prod@prompt 'prodpass' --name 'password' 
ansible-vault encrypt_string --vault-id prod@prompt 'admin' --name 'login' 

ansible-vault encrypt_string --vault-id test@prompt 'testpass' --name 'password' 
ansible-vault encrypt_string --vault-id test@prompt 'admin' --name 'login' 
```

Примерный вывод команды будет:

```
New vault password (test):  # тут пишем пароль для vault
Confirm new vault password (test): # тут повторяем пароль для vault
Encryption successful
pa2ssword: !vault |
          $ANSIBLE_VAULT;1.2;AES256;test
          32386633303665313539656630353338376335373565303531633830303662386136343732646438
          3030613832333735303537336438356137323135303839340a313332313137653539656166313062
          37623238366239633934386239373336333134643166633463363734313538356661336463316135
          3637623262613833620a303161333534313130656563303466616164646539396233326533316561
          3265
```

(!Эти секреты защифрованы с помощью пароля 123 для обоих сред)

Теперь нам доступны секреты, которые мы сохраним в vars/... для каждого из окружений.

Теперь мы можем использовать команды

```
ansible-playbook --vault-id test@prompt -i inventory/testing.yml nginx_install.yml 

ansible-playbook --vault-id prod@prompt -i inventory/production.yml nginx_install.yml 
```

для запуска на testing и production стендах соответсвенно. (после запуска потребует пароль от vault)

Запустим и перейдем по адресу нашего сервера:

![Иллюстрация к проекту](https://github.com/randnull/SRE-hw-17/blob/main/images/auth_req.png)
![Иллюстрация к проекту](https://github.com/randnull/SRE-hw-17/blob/main/images/auth_in.png)


# Краткий список используемых действий:

1. ssh-keygen -t rsa -b 4096 -f ~/.ssh/multipass-ssh-key
2. ssh-add ~/.ssh/multipass-ssh-key
3. Скопировать multipass-ssh-key.pub в cloud-init
4. 
multipass launch -n testvm --cloud-init cloud-init.yaml
multipass launch -n prodvm --cloud-init cloud-init.yaml

5. 
ansible-vault encrypt_string --vault-id prod@prompt 'prodpass' --name 'password' 
ansible-vault encrypt_string --vault-id prod@prompt 'admin' --name 'login' 

ansible-vault encrypt_string --vault-id test@prompt 'testpass' --name 'password' 
ansible-vault encrypt_string --vault-id test@prompt 'admin' --name 'login' 

6. Поместить вывод секретов в папки vars/...
7. Изменить inventory указав адреса хостов из multipass
8. 
Запустить плейбуки:

Либо make create_prod/create_test 
Либо ansible-playbook --vault-id prod@prompt -i inventory/production.yml nginx_install.yml ansible-playbook --vault-id test@prompt -i inventory/testing.yml nginx_install.yml 
