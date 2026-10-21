MEMORY { ROM : ORIGIN = 0x1A000000, LENGTH = 0x2000 }
SECTIONS { .text : { KEEP(*(.vectors)) *(.text*) } > ROM }
ENTRY(_start)
