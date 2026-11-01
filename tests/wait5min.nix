{runCommandLocal}:
runCommandLocal "wait-5-min" {
  # generated randomly during tests to ensure it's never cached
  salt = builtins.getEnv "NIXRUN_NVIM_TEST_SALT";
} ''
  sleep 300
''
