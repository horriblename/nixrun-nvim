{runCommandLocal}:
runCommandLocal "wait-5-min-and-fail" {
  salt = builtins.getEnv "NIXRUN_NVIM_TEST_SALT";
} ''
  sleep 300
  exit 1
''
