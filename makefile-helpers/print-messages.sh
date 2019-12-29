print_success () {
  MESSAGE=$1
  echo "\033[0;32m✔\033[0m $MESSAGE"
}

print_failure () {
  MESSAGE=$1
  echo "\033[0;31m✘\033[0m $MESSAGE"
}