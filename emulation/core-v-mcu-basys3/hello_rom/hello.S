/* Minimal CORE-V-MCU smoke-test boot ROM for the Basys 3 build.
 * Prints a line on uDMA UART0 (PER_ID 0, 0x1A102080) forever.
 * UART0's address is the same before and after the peripheral cuts.
 * periph clk is 5 MHz on the FPGA build: 5e6/115200 -> div 43 (~116 kbaud). */
    .section .vectors, "ax"
    .option norvc
    .rept 32
    j _start            /* any vector / boot address in 0x00..0x7C lands here */
    .endr
    .equ MSG_LEN, 34
    .equ MSG_WORDS, 9
    .global _start
_start:
    li   sp, 0x1C000F00          /* top of private bank 0 (4 KiB on Basys 3) */

    li   t0, 0x1A102000          /* uDMA ctrl */
    li   t1, 1                   /* UART0 = bit 0 */
    lw   t2, 8(t0)
    or   t2, t2, t1
    sw   t2, 8(t0)               /* reg_rst: assert UART0 reset */
    not  t3, t1
    and  t2, t2, t3
    sw   t2, 8(t0)               /* release reset */
    lw   t2, 0(t0)
    or   t2, t2, t1
    sw   t2, 0(t0)               /* reg_cg: enable UART0 clock */

    li   s0, 0x1A102080          /* UART0 */
    li   t1, (43 << 16) | (1 << 8) | (3 << 1)   /* div 43, en_tx, 8 bits */
    sw   t1, 0x24(s0)

    /* copy message from ROM into L2 (uDMA can only read L2) */
    la   t0, msg
    li   t1, 0x1C000000
    li   t2, MSG_WORDS
1:  lw   t3, 0(t0)
    sw   t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    bnez t2, 1b

loop:
2:  lw   t0, 0x14(s0)            /* wait until TX idle */
    bnez t0, 2b
    li   t0, 0x1C000000
    sw   t0, 0x10(s0)            /* tx_saddr */
    li   t0, MSG_LEN
    sw   t0, 0x14(s0)            /* tx_size */
    li   t0, 0x10
    sw   t0, 0x18(s0)            /* tx_cfg.en */
3:  lw   t0, 0x14(s0)
    bnez t0, 3b
    li   t0, 1000000             /* ~0.3 s at 10 MHz */
4:  addi t0, t0, -1
    bnez t0, 4b
    j    loop

    .align 2
msg:
    .ascii "HELLO from CORE-V-MCU on Basys 3\r\n"
msg_end:
    .align 2
