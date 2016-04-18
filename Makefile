NASM = nasm
MKDIR = mkdir
CP = cp
MKISOFS = mkisofs

ASMSRCS = boot/boot.asm kernel/kernel.asm
ASMOBJS = $(ASMSRCS:.asm=.bin)
ASMDEPS = $(ASMSRCS:.asm=.dep)
ASMLISTS = $(ASMSRCS:.asm=.list)

ISONAME = os.iso

default: $(ISONAME)

$(ISONAME): $(ASMOBJS) Makefile
	$(MKDIR) -p cd-root/boot 2>&1 | true
	$(CP) boot/boot.bin cd-root/boot/boot.bin
	$(CP) kernel/kernel.bin cd-root/boot/kernel.bin
	$(MKISOFS) -b boot/boot.bin -hide boot.catalog -no-pad -input-charset iso8859-1 -no-emul-boot -boot-load-seg 0x07c0 -boot-load-size 4 -o $@ cd-root

%.bin: %.asm Makefile
	$(NASM) -f bin $< -o $@ -l $*.list -MD $*.dep -i kernel/ -w+all -w+error

.PHONY: clean
clean:
	rm -rf $(ASMOBJS) $(ASMDEPS) $(ASMLISTS) cd-root

.PHONY: distclean
distclean: clean
	rm -f $(ISONAME)

.PHONY: sync
sync:
	git pull origin master
	git push origin master

-include $(ASMDEPS)
