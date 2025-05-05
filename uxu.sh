#!/bin/bash
# set -euo pipefail
# set -x 





# INSTALLING ESSENTIALS
ensure_jq() {
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi

  echo "⚙️  ‘jq’ not found, attempting to install..."

  # linux distros
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get >/dev/null; then
      sudo apt-get update && sudo apt-get install -y jq
    elif command -v yum >/dev/null; then
      sudo yum install -y epel-release && sudo yum install -y jq
    elif command -v pacman >/dev/null; then
      sudo pacman -Sy --noconfirm jq
    elif command -v zypper >/dev/null; then
      sudo zypper install -y jq
    else
      echo "Error: unsupported Linux distro; please install ‘jq’ manually." >&2
      return 1
    fi

  # macOS
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew >/dev/null; then
      brew install jq
    else
      echo "Error: Homebrew not found; please install Homebrew or jq manually." >&2
      return 1
    fi

  # FreeBSD
  elif [[ "$OSTYPE" == "freebsd"* ]]; then
    sudo pkg install -y jq

  else
    echo "Error: unsupported OS ($OSTYPE); please install ‘jq’ manually." >&2
    return 1
  fi

  # once again cuz why not
  if command -v jq >/dev/null 2>&1; then
    echo "✅ jq installed successfully."
    return 0
  else
    echo "Error: automatic installation of ‘jq’ failed; please install it manually." >&2
    return 1
  fi
}

ensure_jq || exit 1




help() {
  echo "uxu - just a tool to upload and manage files on 0x0.st"
  echo ""
  echo "usage: uxu [command] [-V|h]"
  echo "COMMANDS"
  echo "help    - show this message and exit"
  echo "upload  - upload file on 0x0.st"
  echo "delete  - delete file from 0x0.st"
  echo "list    - list all the files uploaded and their tokens"
  echo ""
  echo "use \"uxu help [command]\" for detailed help with comands"
  echo "Made by pratiksingh94 on Github (https://github.com/pratiksingh94)"
}

help_upload() {
  echo "upload - upload file on 0x0.st"
  echo ""
  echo "usage: \"uxu upload [-f|u|e|s]\""
  echo "OPTIONS   FUNCTION"
  echo "-f        provide file to upload"
  echo "-u        url to upload (use as a url shortner)"
  echo "-e        set file expiry time in hours or milliseconds since epoch"
  echo "-s        toggle secret mode, generates longer url endpoint"
  echo ""
  echo "note: provide either -f or -u not both at same time"
}


DATAFILE="$HOME/.uxu_upload_data.jsonl"
check_data_file() {
  if [[ ! -e "$DATAFILE" ]]; then
    echo "Data file doesnt exist, creating one..."
    touch "$DATAFILE"
    chmod 600 "$DATAFILE"
  fi
  if [[ ! -f "$DATAFILE" || ! -r "$DATAFILE" || ! -w "$DATAFILE" ]]; then
    echo "Error: cannot access data file; please make sure it’s a readable and writable file."
    echo "Or delete it from \$HOME to create a new data file."
    exit 1
  fi
}


if [[ "$1" == "help" ]]; then
  case "$2" in
    "help")
      echo "Are you fucking serious?"
    ;;
    "upload")
      help_upload
    ;;
    "delete")
      echo 3
    ;;
    "list")
      echo 4
    ;;
    *) help
    ;;
  esac
fi


if [[ "$1" == "upload" ]]; then
  shift

  file=
  url=
  expiry=
  secret=

  while getopts ":f:u:e:s" opt; do
    case "$opt" in
      f) file="$OPTARG" ;;
      u) url="$OPTARG" ;;
      e) expiry="$OPTARG" ;;
      s) secret=1 ;;
      *) help_upload ;;
    esac  
  done

  # basic checks
  if [[ -n $file && -n $url ]]; then 
    echo "Error: -f and -u cannot be used together." >&2
    echo "use \"uxu help upload\" to see usage"
    exit 1
  fi

  if [[ -z $file && -z $url ]]; then 
    echo "Error: You must provide -f for file or -u for url to upload." >&2
    echo "use \"uxu help upload\" to see usage"
    exit 1
  fi


  # file checks
  # TODO; PUT EVERY CHECK IN CONDTION TO SEE IF IT EXISTS FIRST OR NOT
  if [[ -n $file ]]; then
    if [[ ! -f $file || ! -r $file ]]; then
      echo "Error: cannot access $file; it either doesn't exist, is not a regular file, or you don't have permission to read it."
      exit 1
    fi
  
    file_size=$(stat -c%s "$file")
    if [[ file_size -gt 512000000 ]]; then
      echo "Error: file is too big, max file size is 512 MB."
      exit 1
    fi
  fi

  # url checks
  if [[ -n $url ]]; then
    headers=$(curl -sI -f "$url") || {
      echo "Error: URL not reachable or returned HTTP error." >&2
      exit 1
    }
    size=$(echo "$headers" \
         | grep -i -m1 '^Content-Length:' \
         | awk '{print $2}' \
         | tr -d '\r')


    if ! echo "$headers" | grep -qi '^Content-Length:'; then
      echo "Error: URL did not return a Content-Length header. (required)" >&2
      exit 1
    fi
  
    if [[ size -gt 512000000 ]]; then
      echo "Error: file is too big, max file size is 512 MB."
      exit 1
    fi
  fi

  # expiry checks
  if [[ -n $expiry ]]; then
    if [[ 0 -gt $expiry ]]; then
      echo "Error: enter a positive number for expiry time, in hours or milliseconds since EPOCH."
      exit 1
    fi
  fi

  # UPLOADING FILE
  curl_args=(
    -X POST "https://0x0.st/"
    -L
    -A "pratiksingh94/uxu (in development) pratik.personal4@gmail.com (you can delete this files)"
    -D /tmp/0x0_headers.txt            
    -o /tmp/0x0_body.txt               
    -w "%{url_effective}"              
    # --trace-ascii /tmp/0x0_curl_trace 
  )

  if [[ -n $file ]]; then
    curl_args+=(-F "file=@$file")
  elif [[ -n $url ]]; then
    curl_args+=(-F "url=$url")
  fi

  if [[ -n $expiry ]]; then
    curl_args+=(-F "expiry=$expiry")
  else
    curl_args+=(-F "expiry=1")
  fi

  if [[ -n $secret ]]; then
    curl_args+=(-F "secret=true")
  fi


  # set +x
  # echo "Running curl with args: ${curl_args[*]}"

  # checking for data file and creating one if not there
  check_data_file

  # Uploading the file
  resp=$(curl "${curl_args[@]}" 2>/dev/null)

  headers=$(< /tmp/0x0_headers.txt)
  body=$(< /tmp/0x0_body.txt)
  upload_url=$(< /tmp/0x0_body.txt)
  
  token=$(grep -i '^X-Token:' /tmp/0x0_headers.txt \
        | awk -F': ' '{print $2}' | tr -d '\r')


  now=$(date +%FT%TZ)
  expiry="${expiry:-1}"
  jq -cn --arg ts "$now" \
        --arg fn "${file:-$url}" \
        --arg fu "${upload_url}" \
        --argjson ex "$expiry" \
        --arg tk "$token" \
       '{timestamp:$ts,file_name:$fn,file_url:$fu,expiry:$ex,token:$tk}' \
  >>"$DATAFILE"




  # DEBUGGING
  # echo
  # echo "====== CURL TRACE ======"
  # cat /tmp/0x0_curl_trace
  # echo
  # echo "====== RESPONSE HEADERS ======"
  # echo "$headers"
  # echo
  # echo "====== RESPONSE BODY ======"
  # echo "$body"
  # echo

  echo "Uploaded succesfully"
  echo "URL: $upload_url"
  echo "Token has been stored in ~/.uxu_upload_data.jsonl"

fi
