package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
)

const destDir = "lua/nixrun/lsp"

func assertOk(err error) {
	if err != nil {
		panic(err)
	}
}

func writePkgInLua(pkg string) string {
	data, err := json.Marshal(pkg)
	assertOk(err)

	return fmt.Sprintf(
		`return {
	package = %s,
}`,
		string(data))
}

func read(fname string) {
	file, err := os.Open(fname)
	assertOk(err)
	count0 := 0
	count1 := 0
	countMulti := 0

	_, err = os.Stat(destDir)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			err = os.MkdirAll(destDir, 0o755)
			assertOk(err)
		} else {
			panic(err)
		}
	}

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		segments := strings.SplitN(line, "=", 2)
		if len(segments) == 0 {
			continue
		}

		name := segments[0]
		if len(segments) == 1 {
			count0++
			continue
		}

		pkgs := strings.Split(segments[1], ",")

		if len(pkgs) == 0 {
			count0++
		} else if len(pkgs) == 1 {
			if pkgs[0] == "" {
				count0++
				continue
			}

			count1++
			err = os.WriteFile(destDir+"/"+name+".lua", []byte(writePkgInLua(pkgs[0])), 0o644)
			assertOk(err)
		} else {
			countMulti++
		}
	}

	println(count0, "have no package")
	println(count1, "found")
	println(countMulti, "have multiple packages")
}

func main() {
	read("gen.txt")
}
