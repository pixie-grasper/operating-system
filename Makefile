NASM = nasm
MKDIR = mkdir
CP = cp
MKISOFS = mkisofs

ASMSRCS = boot.asm kernel.asm
ASMOBJS = $(ASMSRCS:.asm=.bin)

ISONAME = os.iso

default: $(ISONAME)

$(ISONAME): $(ASMOBJS) Makefile
	$(MKDIR) -p cd-root/boot 2>&1 | true
	$(CP) boot.bin cd-root/boot/boot.bin
	$(CP) kernel.bin cd-root/boot/kernel.bin
	$(MKISOFS) -b boot/boot.bin -hide boot.catalog -no-pad -input-charset iso8859-1 -no-emul-boot -boot-load-seg 0x07c0 -boot-load-size 4 -o $@ cd-root

%.bin: %.asm Makefile
	$(NASM) -f bin $< -o $@

.PHONY: clean
clean:
	rm -rf $(OBJS)

.PHONY: sync
sync:
	git pull origin master
	git push origin master

-include $(DEPS)
