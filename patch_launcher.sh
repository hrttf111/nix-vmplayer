csplit launcher.sh "/.*extract_self$/1"

cat xx00 > launcher_patched.sh
cat patch >> launcher_patched.sh
cat xx01 >> launcher_patched.sh

rm xx0*
