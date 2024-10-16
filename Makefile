CC ?= clang
TERMUX_BASE_DIR ?= /data/data/com.termux/files
TERMUX_CACHE_DIR ?= /data/data/com.termux/cache
CFLAGS += -Wall -Wextra -Werror -Wshadow -fvisibility=hidden -std=c17
C_SOURCE := src/termux-exec.c src/exec-variants.c src/termux-readlink.c
CLANG_FORMAT := clang-format --sort-includes --style="{ColumnLimit: 120}" $(C_SOURCE) tests/fexecve.c tests/system-uname.c tests/print-argv0.c tests/popen.c
CLANG_TIDY ?= clang-tidy

ifeq ($(SANITIZE),1)
  CFLAGS += -O1 -g -fsanitize=address -fno-omit-frame-pointer
else
  CFLAGS += -O2
endif

ifeq ($(HOST_BUILD),1)
  CFLAGS += -Wno-error=tautological-pointer-compare
endif

libtermux-exec.so: $(C_SOURCE)
	$(CC) $(CFLAGS) $(LDFLAGS) $(C_SOURCE) -DTERMUX_PREFIX=\"$(TERMUX_PREFIX)\" -DTERMUX_BASE_DIR=\"$(TERMUX_BASE_DIR)\" -DTERMUX_CACHE_DIR=\"$(TERMUX_CACHE_DIR)\" -shared -fPIC -o libtermux-exec.so

tests/fexecve: tests/fexecve.c
	$(CC) $(CFLAGS) -DTERMUX_BASE_DIR=\"$(TERMUX_BASE_DIR)\" $< -o $@

tests/popen: tests/popen.c
	$(CC) $(CFLAGS) -DTERMUX_BASE_DIR=\"$(TERMUX_BASE_DIR)\" $< -o $@

tests/system-uname: tests/system-uname.c
	$(CC) $(CFLAGS) -DTERMUX_BASE_DIR=\"$(TERMUX_BASE_DIR)\" $< -o $@

tests/readlink-proc-self-exe: tests/readlink-proc-self-exe.c
	$(CC) $(CFLAGS) -DTERMUX_BASE_DIR=\"$(TERMUX_BASE_DIR)\" $< -o $@

$(TERMUX_BASE_DIR)/usr/bin/termux-exec-test-print-argv0: tests/print-argv0.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f libtermux-exec.so tests/*-actual test-binary $(TERMUX_BASE_DIR)/usr/bin/termux-exec-test-print-argv0

install: libtermux-exec.so
	install libtermux-exec.so $(DESTDIR)$(PREFIX)/lib/libtermux-exec.so

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/lib/libtermux-exec.so

on-device-tests:
	make clean
	ASAN_OPTIONS=symbolize=0,detect_leaks=0 make on-device-tests-internal

on-device-tests-internal: libtermux-exec.so tests/fexecve tests/popen tests/system-uname tests/readlink-proc-self-exe $(TERMUX_BASE_DIR)/usr/bin/termux-exec-test-print-argv0
	@LD_PRELOAD=${CURDIR}/libtermux-exec.so ./run-tests.sh

format:
	$(CLANG_FORMAT) -i $(C_SOURCE) tests/*.c

check:
	$(CLANG_FORMAT) --dry-run $(C_SOURCE)
	$(CLANG_TIDY) -warnings-as-errors='*' $(C_SOURCE) -- -DTERMUX_BASE_DIR=\"$(TERMUX_BASE_DIR)\"

test-binary: src/termux-exec.c src/exec-variants.c
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -g -fsanitize=address -fno-omit-frame-pointer -DUNIT_TEST=1 -DTERMUX_BASE_DIR=\"$(TERMUX_BASE_DIR)\" -o test-binary

deb: libtermux-exec.so
	termux-create-package termux-exec-debug.json

unit-test: test-binary
	ASAN_OPTIONS=symbolize=0 ./test-binary

.PHONY: clean install uninstall on-device-tests on-device-tests-internal format check deb unit-test
