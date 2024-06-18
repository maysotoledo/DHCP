#!/bin/bash
#
#################################################################################
#################################################################################
# Script que manipula o arquivo /etc/dhcp/dhcpd.conf
#
#
# Coordenação de Tecnologia da Informção
# Campus Barra do Garças
# Dez 2023
#################################################################################
#################################################################################


#####
# Variaveis
#####

DHCP="dhcpd.conf"


##################################################################################

# Verifica se o usuário é o root
if [[ $(id -u) -ne 0 ]]; then
    echo "Este script precisa ser executado com privilégios de root."
    exit 1
fi


# Verifica se a biblioteca ncurses está instalada
if ! dpkg -s libncurses5-dev libncursesw5-dev >/dev/null 2>&1; then
  echo "A biblioteca ncurses não está instalada. Instalando agora..."
  sudo apt-get update
  sudo apt-get install -y libncurses5-dev libncursesw5-dev
fi



################################################### LISTAR USUARIO
listar() {
  echo -e "\033[33mListando de usuários cadastrados:\033[0m"

# Inicializa a lista
usuarios=()

# Obtem a lista de hosts com seus detalhes
hosts=$(grep -E "^\s*host\s+\S+\s+" $DHCP | awk '{print $2}')

# Itera sobre cada host e adiciona as informações na lista
for host in $hosts; do
    mac=$(grep -E "^\s*host\s+$host\s+" -A 2 $DHCP | grep "hardware ethernet" | awk '{gsub(/;/,""); print $3}')
    ip=$(grep -E "^\s*host\s+$host\s+" -A 2 $DHCP | grep "fixed-address" | awk '{gsub(/;/,""); print $2}')

    # Verifica se o MAC e o IP não são vazios antes de adicionar na lista
    if [[ -n $mac ]] && [[ -n $ip ]]; then
        usuarios+=("$host|$mac|$ip")
    fi
done

# Imprime apenas o nome de cada item na lista
for user in "${usuarios[@]}"; do
    nome=$(echo "$user" | cut -d "|" -f 1)
    mac=$(echo "$user" | cut -d "|" -f 2)
    ip=$(echo "$user" | cut -d "|" -f 3)
    echo -e "\033[34mNome:\033[0m $nome, \033[34mMAC:\033[0m $mac, \033[34mIP:\033[0m $ip"
done

}

################################################### ADICIONAR USUARIO
adicionar() {
  echo "Digite o nome do usuário:"
  read nome
  nome=$(echo $nome | tr '[:lower:]' '[:upper:]')

 # Verifica se o Nome já está cadastrado
  nome_cadastrado=$(grep -i "host $nome" $DHCP)
  if [ -n "$nome_cadastrado" ]; then
    echo -e "\033[31mNome já cadastrado\033[0m"
    return 1
  fi
  if [[ -z $nome ]]; then
   echo -e "\033[31mNome Invalido\033[0m"
   return 1
  fi

  echo "Digite o endereço MAC do usuário (formato xx:xx:xx:xx:xx:xx):"
  read mac

  # Verifica se o MAC já está cadastrado
  mac_cadastrado=$(grep -i "hardware ethernet $mac;" $DHCP)
  if [ -n "$mac_cadastrado" ]; then
    echo -e "\033[31mMAC já cadastrado\033[0m"
    return 1
  fi

  if [[ -z $mac ]]; then
    echo -e "\033[31mMAC invalido\033[0m"
    return 1
  fi

  # Obtém o último endereço IP usado no arquivo de configuração do DHCP
  ultimo_ip=$(grep -Eo "([0-9]+\.){3}[0-9]+" $DHCP | grep -v "$ip" | awk -F"." '{print $4}' | sort -n | tail -n 1)
  ip=$(grep -B 4 '#PROXIMO' $DHCP | grep 'fixed-address' | awk '{print $2}')

  if [ -z "$ip" ]; then
    ip="172.16.64.2"
   # Adiciona o primeiro host
  echo -e "\033[32mHost $nome adicionado com IP $ip\033[0m"
  sed -i "/#PROXIMO/i\  host $nome {\n    hardware ethernet $mac;\n    fixed-address $ip;\n  }" $DHCP
    return 1
  fi

  # Incrementa o último octeto do endereço IP para obter o próximo endereço IP disponível
  ip_prefixo=$(echo "$ip" | awk -F"." '{print $1"."$2}')
  ip_3_octeto=$(echo "$ip" | awk -F"." '{print $3}')
  ip_4_octeto=$(echo "$ip" | awk -F"." '{print $4}' | sed 's/;//')

  if [ "$ip_4_octeto" -lt 255 ]; then
    ip_4_octeto=$(expr $ip_4_octeto + 1)
  elif [ "$ip_3_octeto" -lt 67 ]; then
    ip_3_octeto=$(expr $ip_3_octeto + 1)
    ip_4_octeto=1
  else
    echo "Não há mais endereços IP disponíveis"
    return 1
  fi
  
  ip=$ip_prefixo"."$ip_3_octeto"."$ip_4_octeto
  #ip=$(awk -v ip_3_octeto="$ip_3_octeto" -v ip_4_octeto="$ip_4_octeto" 'BEGIN{printf "'"$ip_prefixo"'.%d.%d\n", ip_3_octeto, ip_4_octeto}')

  # Adiciona o novo host
  echo -e "\033[32mHost $nome adicionado com IP $ip\033[0m"
  sed -i "/#PROXIMO/i\  host $nome {\n    hardware ethernet $mac;\n    fixed-address $ip;\n  }" $DHCP
}

################################################### ALTERAR USUARIO
alterar() {
    echo "Informe o Nome do host a ser alterado:"
    read host
    host=$(echo $host | tr '[:lower:]' '[:upper:]')
    # Procura o registro correspondente e armazena as informações em variáveis
    if grep -qE "^\s*host\s+$host\s+" $DHCP; then
        nome=$(grep -E "^\s*host\s+$host\s+" $DHCP | awk '{print $2}')
        nome=$(echo $nome | tr '[:lower:]' '[:upper:]')
        mac=$(grep -E "^\s*host\s+$host\s+" -A 2 $DHCP | grep "hardware ethernet" | awk '{gsub(/;/,""); print $3}')
        ip=$(grep -E "^\s*host\s+$host\s+" -A 2 $DHCP | grep "fixed-address" | awk '{gsub(/;/,""); print $2}')

        # Verifica se o MAC e o IP não são vazios antes de continuar
        if [[ -n $mac ]] && [[ -n $ip ]]; then
            # Solicita o novo nome e MAC do host
            echo "Informe o novo nome do host [$nome]:"
            read novo_nome
            if [[ -z $novo_nome ]]; then
                novo_nome="$nome"
            else
                novo_nome=$(echo $novo_nome | tr '[:lower:]' '[:upper:]')
            fi
            echo "Informe o novo MAC do host [$mac]:"
            read novo_mac
            if [[ -z $novo_mac ]]; then
                novo_mac="$mac"
                 else
                   # Verifica se o MAC já está cadastrado
                   mac_cadastrado=$(grep -i "hardware ethernet $mac;" $DHCP)
                    if [ -n "$mac_cadastrado" ]; then
                     echo -e "\033[31mMAC já cadastrado\033[0m"
                     return 1
                    fi
            fi

            # Substitui o nome e o MAC no registro correspondente do arquivo dhcpd.conf
            sed -i "s/\(host\s\+\)$nome\s\+{/\\1$novo_nome {/g" $DHCP
            sed -i "s/hardware ethernet $mac/hardware ethernet $novo_mac/" $DHCP

            # Imprime a mensagem de sucesso
            echo -e "\033[32mRegistro alterado com sucesso. Novo nome: $novo_nome, Novo MAC: $novo_mac, IP: $ip\033[0m"
        else
            echo -e "\033[31mRegistro inválido. Verifique o Nome e tente novamente.\033[0m"
        fi
    else
        echo -e "\033[31mRegistro não encontrado. Verifique o Nome e tente novamente.\033[0m"
    fi
}
################################################### BUSCAR USUARIO

buscar() {
options=("Nome" "MAC" "IP")

# Variável que armazena a opção selecionada
selected_option=0


# Função que exibe o menu
show_menu() {
  # Desabilita o cursor na tela
  tput civis


  clear
  echo "Escolha uma opção:"
  for i in "${!options[@]}"; do
    if [ $i -eq $selected_option ]; then
      # Exibe a opção selecionada com fundo azul
      echo -e "\033[44m ${options[$i]} \033[0m"
    else
      echo "   ${options[$i]}"
    fi
  done
}


# Inicializa a biblioteca ncurses
tput init

# Habilita a captura de caracteres especiais
stty -echo -icanon time 0 min 0

# Exibe o menu inicial
show_menu



# Loop que processa as teclas pressionadas pelo usuário
while true; do
  # Lê o próximo caractere de entrada
  read -s -n1 key
  case $key in
    A) # Se a tecla pressionada foi a seta para cima, decrementa o índice da opção selecionada
      selected_option=$((selected_option - 1))
      if [ $selected_option -lt 0 ]; then
        selected_option=$((${#options[@]} - 1))
      fi
      show_menu
      ;;
    B) # Se a tecla pressionada foi a seta para baixo, incrementa o índice da opção selecionada
      selected_option=$((selected_option + 1))
      if [ $selected_option -ge ${#options[@]} ]; then
        selected_option=0
      fi
      show_menu
      ;;
    "") # Se a tecla pressionada foi Enter, sai do loop e retorna a opção selecionada
      break
      ;;
  esac
done

# Desabilita a captura de caracteres especiais
stty echo icanon

# Finaliza a biblioteca ncurses
tput reset

# Habilita o cursor na tela novamente
tput cnorm

# Retorna a opção selecionada
# echo "Você selecionou a opção $(($selected_option + 1)) -  ${options[$selected_option]} "

if [ $(($selected_option + 1)) -eq 1 ]; then
        echo "Digite o nome do usuário:"
      read nome
      nome=$(echo $nome | tr '[:lower:]' '[:upper:]')
      if grep -qE "^\s*host\s+$nome\s+" $DHCP; then
        mac=$(grep -E "^\s*host\s+$nome\s+" -A 2 $DHCP | grep "hardware ethernet" | awk '{gsub(/;/,""); print $3}')
        ip=$(grep -E "^\s*host\s+$nome\s+" -A 2 $DHCP | grep "fixed-address" | awk '{gsub(/;/,""); print $2}')
        echo "Nome: $nome, MAC: $mac, IP: $ip"
      else
        echo -e "\033[31mUsuário não encontrado\033[0m"
        return 1
      fi
fi

if [ $(($selected_option + 1)) -eq 2 ]; then
       echo "Digite o endereço MAC do usuário (formato xx:xx:xx:xx:xx:xx):"
      read mac
      if [[ -n $mac ]] && grep -qE "hardware ethernet\s+$mac" $DHCP; then
        nome=$(grep -iE "hardware ethernet\s+$mac" -B 2 $DHCP | grep "host" | awk '{print $2}' )
        ip=$(grep -iE "hardware ethernet\s+$mac" -A 2 $DHCP | grep "fixed-address" | awk '{print $2}' )
        echo "Nome: $nome, MAC: $mac, IP: $ip"
      else
        echo -e "\033[31mUsuário não encontrado\033[0m"
        return 1
      fi
fi

if [ $(($selected_option + 1)) -eq 3 ]; then
       echo "Digite o endereço IP do usuário (formato xxx.xxx.xxx.xxx):"
      read ip
      if [[ -n $ip ]] && grep -qE "fixed-address\s+$ip" $DHCP; then
        nome=$(grep -iE "fixed-address\s+$ip" -B 2 $DHCP | grep "host" | awk '{print $2}')
        mac=$(grep -iE "fixed-address\s+$ip" -B 2 $DHCP | grep "hardware ethernet" | awk '{print $3}' | tr -d ';')
        echo "Nome: $nome, MAC: $mac, IP: $ip"
      else
        echo -e "\033[31mUsuário não encontrado\033[0m"
        return 1
      fi
fi

}

################################################### LISTAR ACESSOS
acesso() {

options=("MAC especifico" "Todos usuarios")

# Variável que armazena a opção selecionada
selected_option=0


# Função que exibe o menu
show_menu() {
  # Desabilita o cursor na tela
  tput civis


  clear
  echo "Escolha uma opção:"
  for i in "${!options[@]}"; do
    if [ $i -eq $selected_option ]; then
      # Exibe a opção selecionada com fundo azul
      echo -e "\033[44m ${options[$i]} \033[0m"
    else
      echo "   ${options[$i]}"
    fi
  done
}


# Inicializa a biblioteca ncurses
tput init

# Habilita a captura de caracteres especiais
stty -echo -icanon time 0 min 0

# Exibe o menu inicial
show_menu



# Loop que processa as teclas pressionadas pelo usuário
while true; do
  # Lê o próximo caractere de entrada
  read -s -n1 key
  case $key in
    A) # Se a tecla pressionada foi a seta para cima, decrementa o índice da opção selecionada
      selected_option=$((selected_option - 1))
      if [ $selected_option -lt 0 ]; then
        selected_option=$((${#options[@]} - 1))
      fi
      show_menu
      ;;
    B) # Se a tecla pressionada foi a seta para baixo, incrementa o índice da opção selecionada
      selected_option=$((selected_option + 1))
      if [ $selected_option -ge ${#options[@]} ]; then
        selected_option=0
      fi
      show_menu
      ;;
    "") # Se a tecla pressionada foi Enter, sai do loop e retorna a opção selecionada
      break
      ;;
  esac
done

# Desabilita a captura de caracteres especiais
stty echo icanon

# Finaliza a biblioteca ncurses
tput reset

# Habilita o cursor na tela novamente
tput cnorm

# Retorna a opção selecionada
# echo "Você selecionou a opção $(($selected_option + 1)) -  ${options[$selected_option]} "


if [ $(($selected_option + 1)) -eq 1 ]; then
 # Solicita o MAC do usuário a ser listado
    echo "Informe o MAC do usuário:"
    read mac_address
    # Procurar o endereço IP mais recente atribuído para o endereço MAC especificado
    ip_address=$(grep "DHCPACK.*${mac_address}" /var/log/syslog | tail -n 1 | awk '{print $9}')

    # Se houver um endereço IP atribuído para o endereço MAC especificado, imprimir a data da última atribuição
    if [[ -n $ip_address ]]; then
         last_date=$(grep "DHCPACK.*${mac_address}" /var/log/syslog | tail -n 1 | awk '{print $1, $2, $3}')
         echo "O endereço MAC $mac_address foi atribuído com o endereço IP $ip_address pela última vez em $last_date."
       else
         echo "MAC nao fez nenhum acesso!" 
    fi
fi
if [ $(($selected_option + 1)) -eq 2 ]; then

 # Inicializa a lista
 usuarios=()

 # Obtem a lista de hosts com seus detalhes
 hosts=$(grep -E "^\s*host\s+\S+\s+" $DHCP | awk '{print $2}')

 # Itera sobre cada host e adiciona as informações na lista
 for host in $hosts; do
    mac=$(grep -E "^\s*host\s+$host\s+" -A 2 $DHCP | grep "hardware ethernet" | awk '{gsub(/;/,""); print $3}')
    ip=$(grep -E "^\s*host\s+$host\s+" -A 2 $DHCP | grep "fixed-address" | awk '{gsub(/;/,""); print $2}')

    # Verifica se o MAC e o IP não são vazios antes de adicionar na lista
    if [[ -n $mac ]] && [[ -n $ip ]]; then
        usuarios+=("$host|$mac|$ip")
    fi
 done

 # Imprime apenas o nome de cada item na lista
 for user in "${usuarios[@]}"; do
    nome=$(echo "$user" | cut -d "|" -f 1)
    mac=$(echo "$user" | cut -d "|" -f 2)
    ip=$(echo "$user" | cut -d "|" -f 3)
    acesso=$(grep "DHCPACK.*${mac}" /var/log/syslog | tail -n 1 | awk '{print $1, $2, $3}')
    if [[ -n $acesso ]]; then
      echo "$nome|$mac|$ip - $acesso"
    else
      echo -e "\033[31m$nome|$mac|$ip\033[0m"
    fi
 done | sort -k 9,9 -k 6,7 -k 4,5 -r

fi

}




##########################################################################################################################
##########################################################################################################################

# Array com as opções do menu


while true; do
options=("Cadastrar Usuario" "Listar Usuarios" "Buscar Usuario" "Acessos Usuarios" "Alterar Usuario" "Sair")

# Variável que armazena a opção selecionada
selected_option=0


# Função que exibe o menu
show_menu() {
  # Desabilita o cursor na tela
  tput civis


  clear
  echo "Escolha uma opção:"
  for i in "${!options[@]}"; do
    if [ $i -eq $selected_option ]; then
      # Exibe a opção selecionada com fundo azul
      echo -e "\033[44m ${options[$i]} \033[0m"
    else
      echo "   ${options[$i]}"
    fi
  done
}


# Inicializa a biblioteca ncurses
tput init

# Habilita a captura de caracteres especiais
stty -echo -icanon time 0 min 0

# Exibe o menu inicial
show_menu



# Loop que processa as teclas pressionadas pelo usuário
while true; do
  # Lê o próximo caractere de entrada
  read -s -n1 key
  case $key in
    A) # Se a tecla pressionada foi a seta para cima, decrementa o índice da opção selecionada
      selected_option=$((selected_option - 1))
      if [ $selected_option -lt 0 ]; then
        selected_option=$((${#options[@]} - 1))
      fi
      show_menu
      ;;
    B) # Se a tecla pressionada foi a seta para baixo, incrementa o índice da opção selecionada
      selected_option=$((selected_option + 1))
      if [ $selected_option -ge ${#options[@]} ]; then
        selected_option=0
      fi
      show_menu
      ;;
    "") # Se a tecla pressionada foi Enter, sai do loop e retorna a opção selecionada
      break
      ;;
  esac
done

# Desabilita a captura de caracteres especiais
stty echo icanon

# Finaliza a biblioteca ncurses
tput reset

# Habilita o cursor na tela novamente
tput cnorm

# Retorna a opção selecionada
# echo "Você selecionou a opção $(($selected_option + 1)) -  ${options[$selected_option]} "

if [ $(($selected_option + 1)) -eq 1 ]; then
  adicionar
fi

if [ $(($selected_option + 1)) -eq 2 ]; then
  listar
fi

if [ $(($selected_option + 1)) -eq 3 ]; then
  buscar
fi

if [ $(($selected_option + 1)) -eq 4 ]; then
  acesso
fi

if [ $(($selected_option + 1)) -eq 5 ]; then
  alterar
fi

if [ $(($selected_option + 1)) -eq 6 ]; then
 break
fi

echo ""
echo "precione <Enter> para voltar ao menu!"
read t

done
