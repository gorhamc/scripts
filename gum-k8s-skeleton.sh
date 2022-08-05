#!/bin/sh

login_check () {
  if [ "$SERVICE" != "$ACTIVE_SERVICE" ]; then
    login
  fi
}

### Setup ENV vars to be used by kubectl
### each service you want to look at will need a function like this. Or to make it more scalable, move to a config file and read it in perhaps?
service1_env () {
  REGION="us-west1"
  NAMESPACE="service1"
  if [ "$SERVICE_ENV" = "dev" ]; then
      GCP_PROJECT_ID=""
      PAAS_ENV=""
      PAAS_PROJECT=""
  else
    echo "service1 only has dev for right now, sorry"
    exit 0
  fi
}

service2_env () {
  REGION="us-west1"
  NAMESPACE="service2"
  if [ $SERVICE_ENV = "prd" ]; then
    GCP_PROJECT_ID=""
    PAAS_ENV=""
    PAAS_PROJECT=""
  elif [ $SERVICE_ENV = "stg" ]; then
    GCP_PROJECT_ID=""
    PAAS_ENV=""
    PAAS_PROJECT=""
  else # default to dev
    GCP_PROJECT_ID=""
    PAAS_ENV=""
    PAAS_PROJECT=""
  fi
}

service3_env () {
  REGION="us-west1"
  NAMESPACE="service3"
  if [ "$SERVICE_ENV" = "prd" ]; then
    GCP_PROJECT_ID=""
    PAAS_ENV=""
    PAAS_PROJECT=""
  elif [ "$SERVICE_ENV" = "stg" ]; then
    GCP_PROJECT_ID=""
    PAAS_ENV=""
    PAAS_PROJECT=""
  else # default to dev
    GCP_PROJECT_ID=""
    PAAS_ENV=""
    PAAS_PROJECT=""
  fi
}

run_cmd () {
  if [ "$SERVICE" = "service1" ]; then
    service1_env
  elif [ "$SERVICE" = "service2" ]; then
    service2_env
  elif [ "$SERVICE" = "service3" ]; then
    service3_env
  fi

  if [ "$CMD" = "login" ]; then
    login
  fi

  if [ "$CMD" = "logs" ]; then
    login_check
    logs
  fi

  if [ "$CMD" = "pods" ]; then
    login_check
    pods
  fi

  if [ "$CMD" = "namespace_events" ]; then
    login_check
    namespace_events
  fi

  if [ "$CMD" = "pod_events" ]; then
    login_check
    pod_events
  fi

  if [ "$CMD" = "describe" ]; then
    login_check
    describe
  fi
}

select_pod() {
  POD=$(gum spin -s dot --title "selecting pod" --show-output -- kubectl get pods | awk '{if(NR>1)print}' | gum filter | cut -f 1 -d " ")
}

describe () {
  echo "describe pod"
  select_pod
  gum spin -s dot --title "describing pod" --show-output -- kubectl describe pod $POD
}

logs () {
  echo "getting pod logs"
  select_pod
  CONTAINER=$(kubectl get -o go-template pod/$POD --template="{{range .spec.containers}}{{.name}} {{end}}")
  C=$(gum choose $CONTAINER)
  gum spin --spinner="dot" --show-output --title "getting logs for $POD" -- kubectl logs $POD -c $C
}

login () {
  gum spin -s line --title "setting gcloud project" -- gcloud config set project $GCP_PROJECT_ID
  gum spin -s line --title  "running gcloud container get creds command" -- gcloud container clusters get-credentials $PAAS_ENV --project $PAAS_PROJECT --region $REGION
  gum spin -s line --title  "setting kube ctx namespace" -- kubectl config set-context --current --namespace=$NAMESPACE
  ACTIVE_SERVICE="$SERVICE"
  gum style \
  --foreground 212 --border-foreground 212 --border double \
  --align center --width 50 --margin "1 2" --padding "2 4" \
  "$ACTIVE_SERVICE"
}

pods () {
  gum spin --spinner="dot" --show-output --title "fetching pods" -- kubectl get pods
}

namespace_events () {
  gum spin --spinner="dot" --show-output --title "getting namespace events" -- kubectl get events --field-selector involvedObject.namespace=$NAMESPACE
}

pod_events () {
  echo "getting pod_events events"
  select_pod
  gum spin --spinner="dot" --show-output --title "getting pod events" -- kubectl get events --field-selector involvedObject.name=$POD,involvedObject.namespace=$NAMESPACE,involvedObject.kind="Pod"
}

menu () {
  choose_service
}

choose_service () {
  SERVICE=$(gum choose "service1" "service2" "service3" "quit")
  if [ "$SERVICE" = "quit" ]; then
    echo "bye!"
    exit 0
  fi
  choose_env
}

choose_env () {
    SERVICE_ENV=$(gum choose "dev" "stg" "prd" "back")
    if [ "$SERVICE_ENV" = "back" ]; then
      menu
    fi
    choose_cmd
}

choose_cmd () {
  CMD=$(gum choose "logs" "pods" "namespace_events" "pod_events" "describe" "back")
  if [ "$CMD" = "back" ]; then
    menu
  fi
  run_cmd
}

begin () {
  menu
  while [ "$CMD" != "back" ]
  do
    choose_cmd
  done
}

_prereq () {
  OS=$(uname 2>/dev/null || echo Unknown)
  if ! [ $(command -v gum) ]; then
      if [ "$OS" = "Darwin" ]; then
        echo "gum could not be found, installing via brew"
        brew install gum
      elif [ "$OS" = "Linux" ] && [ $(cat /etc/*-release | grep Ubuntu | wc -c) -ne 0 ]; then
	  echo "gum could not be found, installing via apt"
          echo 'deb [trusted=yes] https://repo.charm.sh/apt/ /' | sudo tee /etc/apt/sources.list.d/charm.list
          sudo apt update && sudo apt install gum
      else
        echo "gum could not be found, installing via Go"
        go install github.com/charmbracelet/gum@latest
      fi
  fi

  if ! [ $(command -v kubectl) ]; then
      echo "kubectl could not be found, installing"
      if [ "$OS" = "Darwin" ]; then
        brew install kubectl
      else
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
        echo "$(cat kubectl.sha256)  kubectl" | shasum -a 256 --check
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
        sudo chown root: /usr/local/bin/kubectl
      fi
  fi

  if ! [ $(command -v gcloud) ] ; then
      echo "you need to install google-cloud-sdk for gcloud cli. I'm too lazy to script this right now. good luck"
      exit 0
  fi
}

#IT BEGINS!! Run script
_prereq
begin