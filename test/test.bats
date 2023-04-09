setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  # get the containing directory of this file
  # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
  # as those will point to the bats executable's location or the preprocessed file respectively
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  DIR="${DIR/test/src}" # replace 'test' with 'src'
  # make executables in src/ visible to PATH
  PATH="$DIR:$PATH"
}

@test "Calling cpodctl without arguments should work" {
  run cpodctl
}

@test "Calling cpodctl with wrong argument should return message" {
  run cpodctl wrong_argument
  assert_output "\"wrong_argument\" is not an argument or command. Use \"help\" in order to list all verbs."
}

@test "Calling cpodctl list should print out an empty list of cPods" {
  run cpodctl list
  assert_output --partial "List of cPods"
}