APP      := Avenger
BIN      := avenger
BUILD    := build
OBJDIR   := $(BUILD)/obj
BUNDLE   := $(BUILD)/$(APP).app
EXE      := $(BUNDLE)/Contents/MacOS/$(BIN)

CC       := clang
ARCH     := -arch arm64 -mmacosx-version-min=13.0
ASFLAGS  := $(ARCH) -I include
LDFLAGS  := $(ARCH) -framework AppKit -framework CoreText -framework CoreGraphics \
            -lobjc -Wl,-dead_strip -Wl,-x

SRCS     := $(wildcard src/*.s)
OBJS     := $(patsubst src/%.s,$(OBJDIR)/%.o,$(SRCS))
INCS     := $(wildcard include/*.inc)

.PHONY: all run clean size

all: $(EXE) $(BUNDLE)/Contents/Info.plist
	@codesign -s - --force $(BUNDLE) 2>/dev/null

$(OBJDIR)/%.o: src/%.s $(INCS) | $(OBJDIR)
	$(CC) $(ASFLAGS) -c $< -o $@

$(EXE): $(OBJS) | $(BUNDLE)/Contents/MacOS
	$(CC) $(LDFLAGS) $(OBJS) -o $@
	strip -x $@

$(BUNDLE)/Contents/Info.plist: Info.plist | $(BUNDLE)/Contents/MacOS
	cp $< $@

$(OBJDIR) $(BUNDLE)/Contents/MacOS:
	mkdir -p $@

run: all
	open $(BUNDLE)

size: all
	@ls -l $(EXE) | awk '{print $$5 " bytes"}'
	@size -m $(EXE) | grep -E 'Section|Segment' | head -20

clean:
	rm -rf $(BUILD)
