APP      := Avenger
BIN      := avenger
BUILD    := build
OBJDIR   := $(BUILD)/obj
BUNDLE   := $(BUILD)/$(APP).app
EXE      := $(BUNDLE)/Contents/MacOS/$(BIN)

CC       := clang
ARCH     := -arch arm64 -mmacosx-version-min=13.0
ASFLAGS  := $(ARCH) -I include -I tests
LDFLAGS  := $(ARCH) -framework AppKit -framework CoreText -framework CoreGraphics \
            -lobjc -Wl,-dead_strip -Wl,-x

SRCS     := $(wildcard src/*.s)
OBJS     := $(patsubst src/%.s,$(OBJDIR)/%.o,$(SRCS))
INCS     := $(wildcard include/*.inc)

# core modules have no AppKit dependency and link into CLI test binaries
CORE     := alloc buffer file doc edit theme yaml config hl keymap
CORE_OBJS := $(patsubst %,$(OBJDIR)/%.o,$(CORE))
TESTS    := $(patsubst tests/%.s,$(BUILD)/%,$(wildcard tests/test_*.s))

.PHONY: all run clean size test yamlcheck

all: $(EXE) $(BUNDLE)/Contents/Info.plist
	@codesign -s - --force $(BUNDLE) 2>/dev/null

$(OBJDIR)/%.o: src/%.s $(INCS) | $(OBJDIR)
	$(CC) $(ASFLAGS) -c $< -o $@

# tabs.s embeds the config template
$(OBJDIR)/tabs.o: config.example.yaml

$(EXE): $(OBJS) | $(BUNDLE)/Contents/MacOS
	$(CC) $(LDFLAGS) $(OBJS) -o $@
	strip -x $@

$(BUNDLE)/Contents/Info.plist: Info.plist | $(BUNDLE)/Contents/MacOS
	cp $< $@

$(OBJDIR) $(BUNDLE)/Contents/MacOS:
	mkdir -p $@

$(BUILD)/test_%: tests/test_%.s tests/harness.inc $(CORE_OBJS) $(INCS)
	$(CC) $(ASFLAGS) $< $(CORE_OBJS) -o $@

test: $(TESTS)
	@for t in $(TESTS); do echo "== $$t"; ./$$t || exit 1; done

run: all
	open $(BUNDLE)

size: all
	@ls -l $(EXE) | awk '{print $$5 " bytes"}'
	@size -m $(EXE) | grep -E 'Section|Segment' | head -20

clean:
	rm -rf $(BUILD)

$(BUILD)/yamlcheck: tools/yamlcheck.s $(CORE_OBJS) $(INCS)
	$(CC) $(ASFLAGS) $< $(CORE_OBJS) -o $@

yamlcheck: $(BUILD)/yamlcheck
