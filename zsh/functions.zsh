function mdcd {
    mkdir $1
    cd $1
}

function up {
    COUNT=1
    if [[ "$1" ]]; then
        COUNT="$1"
    fi
    DIR=.
    for ((I=0; $I < $COUNT; I=$I+1)); do
        DIR=$DIR/..
    done
    cd $DIR
}

switch_java_test() {
  local newdir
  case "$PWD" in
    */java/*)
      newdir="${PWD/java/javatests}"
      ;;
    */javatests/*)
      newdir="${PWD/javatests/java}"
      ;;
    *)
      echo "Not in a java or javatests path" >&2
      return 1
      ;;
  esac
  cd "$newdir" || echo "Target directory doesn't exist: $newdir"
}
alias jt='switch_java_test'

# Find previous command (semantic prompt marks)
preexec () {
    echo -n "\\x1b]133;A\\x1b\\"
}
