test:
	rooch move test --skip-fetch-latest-git-deps --ignore_compile_warnings -i 1000000000000000 -g
build:
	rooch move build --skip-fetch-latest-git-deps --ignore_compile_warnings -i 1000000000000000 -g