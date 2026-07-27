@---------------------------------------------------------------------------------
	.section ".init"
@---------------------------------------------------------------------------------
	.global _start
	.type _start STT_FUNC
	.align	4
	.arm

@---------------------------------------------------------------------------------
_start:
@---------------------------------------------------------------------------------
	b reset_vector 		@ 0x00 Reset
	b reserved_vector		@ 0x04 Undefined
	b swi_vector			@ 0x08 SWI
	b reserved_vector 	@ 0x0C Abort Prefetch
	b reserved_vector 	@ 0x10 Abort Data
	b reserved_vector		@ 0x14 Reserved
	b irq_vector			@ 0x18 IRQ
	b irq_vector			@ 0x1C FIQ
	
@---------------------------------------------------------------------------------
irq_vector:
@---------------------------------------------------------------------------------	
	@ Save these registers, IRQ functions will be allowed to modify them w/o
	@ saving.
	stmdb sp!, { r0 - r3, r12, lr }
	
	@ Pointer to IRQ handler is at 0x03FFFFFC (mirrored WRAM)
	mov r0, #0x04000000
	
	@ Store return address and branch to handler
	mov lr, pc
	ldr pc, [ r0, #-4 ]

	@ Return from IRQ
	ldmia sp!, { r0 - r3, r12, lr }
	subs pc, lr, #4

@---------------------------------------------------------------------------------
reset_vector: @This isn't required if not booting from bios
@---------------------------------------------------------------------------------	
	mov     r0, #0xDF
	msr     cpsr_cf, r0
	
	@Disable Interrupts IME=0
	mov     r3, #0x04000000
	strb    r3, [r3,#0x208]
	
	@Setup stacks
	bl      init
	
	mov r2, #1
	strb    r2, [r3,#0x208]
	
	ldr   r0, =DrawLogo
	ldr   lr, =swi_SoftReset
	bx r0
	
@---------------------------------------------------------------------------------
reserved_vector: @Lets just infinite loop for now
@---------------------------------------------------------------------------------	
	b reserved_vector
	
@ SWI calling convention:
@ Parameters are passed in via r0 - r3
@ Called SWI can modify r0 - r3 (and return things here), r12, and r14.
@ They can't modify anything else.
@---------------------------------------------------------------------------------
swi_vector:
@---------------------------------------------------------------------------------	
	@ Save these as temporaries
	stmdb sp!, { r11, r12, lr }
	
	@ Load comment from SWI instruction, which indicates which SWI
	@ to use.
	ldrb r12, [lr,#-2]
	adr r11, swi_branch_table
	ldr r12, [r11,r12,lsl#2]
	
	@ get SPSR and enter system mode, interrupts on
	MRS R11, SPSR
	@ This must be stacked and not just saved, because otherwise SWI won't
	@ be reentrant, which can happen if you're waiting for interrupts and the
	@ interrupt handler triggers the SWI.
	stmfd sp!, {r11}
	
	@ Set up new CPSR value
	and r11, r11, #0x80
	orr r11, r11, #0x1f
	msr cpsr_cf, r11
	
	@ Save system-mode lr (and r2 scratch). Match the official BIOS frame
	@ size: Minish Cap's IRQ handler switches to System mode and will
	@ corrupt a larger SWI frame on the System stack (IntrWait softlock).
	stmfd sp!, {r2, lr}
	
	@ Set return address
	adr lr, swi_complete
	@ Branch to SWI handler
	bx r12
	
swi_complete:
	@ Restore system mode lr
	ldmfd sp!, {r2, lr}
	
	@ Go back to supervisor mode to get back to that stack
	mov r12, #0xD3
	msr cpsr_cf, r12
	
	@ SPSR has to be restored because the transition to system mode broke it
	ldmfd sp!, {r11}
	msr spsr_cf, r11
	
	@ Restore stuff we saved
	ldmfd sp!, {r11,r12,lr}
	
	@ Return from exception handler
	movs pc, lr

# The GBA maps this image at 0x00000000, but devkitARM links it at 0x08000000.
# Branch-table words must be low BIOS addresses (bx targets), not ROM VMAs.
#define BIOS_vma_fix(sym) (sym - 0x08000000)

@---------------------------------------------------------------------------------
swi_branch_table:
@---------------------------------------------------------------------------------
	.word BIOS_vma_fix(swi_SoftReset)					@ 0x00_SoftReset
	.word BIOS_vma_fix(swi_RegisterRamReset)			@ 0x01_RegisterRAMReset
	.word BIOS_vma_fix(swi_Halt)						@ 0x02_Halt
	.word BIOS_vma_fix(swi_Stop)						@ 0x03_Stop
	.word BIOS_vma_fix(swi_IntrWait)					@ 0x04_IntrWait
	.word BIOS_vma_fix(swi_VBlankIntrWait)				@ 0x05_VBlankIntrWait
	.word BIOS_vma_fix(swi_Div)						@ 0x06_Div
	.word BIOS_vma_fix(swi_DivARM)					@ 0x07_DivARM
	.word BIOS_vma_fix(swi_Sqrt)						@ 0x08_Sqrt
	.word BIOS_vma_fix(swi_ArcTan)						@ 0x09_ArcTan
	.word BIOS_vma_fix(swi_ArcTan2)					@ 0x0A_ArcTan2
	.word BIOS_vma_fix(swi_CpuSet)					@ 0x0B_CPUSet
	.word BIOS_vma_fix(swi_CpuFastSet)					@ 0x0C_CPUFastSet
	.word BIOS_vma_fix(swi_GetBiosChecksum)			@ 0x0D_GetBiosChecksum
	.word BIOS_vma_fix(swi_BgAffineSet)					@ 0x0E_BgAffineSet
	.word BIOS_vma_fix(swi_ObjAffineSet)				@ 0x0F_ObjAffineSet
	.word BIOS_vma_fix(swi_BitUnPack)					@ 0x10_BitUnPack
	.word BIOS_vma_fix(swi_LZ77UnCompWram)			@ 0x11_LZ77UnCompWram
	.word BIOS_vma_fix(swi_LZ77UnCompVram)			@ 0x12_LZ77UnCompVram
	.word BIOS_vma_fix(swi_HuffUnComp)				@ 0x13_HuffUnComp
	.word BIOS_vma_fix(swi_RLUnCompWram)			@ 0x14_RLUnCompWram
	.word BIOS_vma_fix(swi_RLUnCompVram)			@ 0x15_RLUnCompVram
	.word BIOS_vma_fix(swi_Diff8bitUnFilterWram)			@ 0x16_Diff8bitUnFilterWram
	.word BIOS_vma_fix(swi_Diff8bitUnFilterVram)			@ 0x17_Diff8bitUnFilterVram
	.word BIOS_vma_fix(swi_Diff16bitUnFilter)				@ 0x18_Diff16bitUnFilter
	.word BIOS_vma_fix(swi_Invalid)						@ 0x19_SoundBiasChange
	.word BIOS_vma_fix(swi_Invalid)						@ 0x1A_SoundDriverInit
	.word BIOS_vma_fix(swi_Invalid)						@ 0x1B_SoundDriverMode
	.word BIOS_vma_fix(swi_Invalid)						@ 0x1C_SoundDriverMain
	.word BIOS_vma_fix(swi_Invalid)						@ 0x1D_SoundDriverVSync
	.word BIOS_vma_fix(swi_Invalid)						@ 0x1E_SoundChannelClear
	.word BIOS_vma_fix(swi_MidiKey2Freq)				@ 0x1F_MidiKey2Freq
	.word BIOS_vma_fix(swi_Invalid)						@ 0x20_MusicPlayerOpen
	.word BIOS_vma_fix(swi_Invalid)						@ 0x21_MusicPlayerStart
	.word BIOS_vma_fix(swi_Invalid)						@ 0x22_MusicPlayerStop
	.word BIOS_vma_fix(swi_MusicPlayerContinue)			@ 0x23_MusicPlayerContinue
	.word BIOS_vma_fix(swi_MusicPlayerFadeOut)			@ 0x24_MusicPlayerFadeOut
	.word BIOS_vma_fix(swi_Invalid)						@ 0x25_MultiBoot
	.word BIOS_vma_fix(swi_Invalid)						@ 0x26_HardReset
	.word BIOS_vma_fix(swi_CustomHalt)					@ 0x27_CustomHalt
	.word BIOS_vma_fix(swi_Invalid)						@ 0x28_SoundDriverVSyncOff
	.word BIOS_vma_fix(swi_Invalid)						@ 0x29_SoundDriverVSyncOn
	.word BIOS_vma_fix(swi_SoundGetJumpList)			@ 0x2A_SoundGetJumpList

@---------------------------------------------------------------------------------
@ Halt / Stop / CustomHalt — match official BIOS register usage.
@ Official only touches r2 and ip (r12). Metroid Fusion's VBlank wait keeps
@ r3=1 across SWI 0x02 and ANDs it with a software IRQ flag afterwards; the
@ old C Halt (ldr base into r3) cleared that and softlocked on a black screen.
@---------------------------------------------------------------------------------
	.global swi_Halt
	.type swi_Halt STT_FUNC
swi_Halt:
	mov	r2, #0
	b	halt_write

	.global swi_Stop
	.type swi_Stop STT_FUNC
swi_Stop:
	mov	r2, #0x80
	@ fall through
halt_write:
	mov	ip, #0x04000000
	strb	r2, [ip, #0x301]
	bx	lr

	.global swi_CustomHalt
	.type swi_CustomHalt STT_FUNC
swi_CustomHalt:
	@ r0 = HALTCNT value (GBATEK). Use ip only besides r0.
	mov	ip, #0x04000000
	strb	r0, [ip, #0x301]
	bx	lr

@---------------------------------------------------------------------------------
@ IntrWait / VBlankIntrWait — same algorithm as the official GBA BIOS.
@ The previous C versions were miscompiled: after the discard CheckInterrupts()
@ call, r0 (waitFlags) was overwritten by the return value, so the Halt loop
@ waited for flags==0 forever (Minish Cap file-select softlock with open BIOS).
@---------------------------------------------------------------------------------
	.global swi_VBlankIntrWait
	.type swi_VBlankIntrWait STT_FUNC
swi_VBlankIntrWait:
	mov	r0, #1
	mov	r1, #1
	@ fall through

	.global swi_IntrWait
	.type swi_IntrWait STT_FUNC
swi_IntrWait:
	stmfd	sp!, {r4, lr}
	mov	r3, #0
	mov	r4, #1
	mov	ip, #0x04000000		@ so HALTCNT write is valid even if discard==0
	cmp	r0, #0
	blne	intrwait_check
intrwait_loop:
	@ HALTCNT = 0. ip is set by intrwait_check (discard path or prior iter).
	strb	r3, [ip, #0x301]
	bl	intrwait_check
	beq	intrwait_loop
	ldmfd	sp!, {r4, lr}
	bx	lr

@ r1 = waitFlags (preserved). Returns Z clear if a waited IRQ was seen.
intrwait_check:
	mov	ip, #0x04000000
	strb	r3, [ip, #0x208]		@ REG_IME = 0
	ldrh	r2, [ip, #-8]		@ REG_IFBIOS
	ands	r0, r1, r2
	eorne	r2, r2, r0
	strneh	r2, [ip, #-8]
	strb	r4, [ip, #0x208]		@ REG_IME = 1
	bx	lr
	
@---------------------------------------------------------------------------------
.global swi_Invalid
.type swi_Invalid STT_FUNC
swi_Invalid:
@---------------------------------------------------------------------------------
	@ Infinite loop for now
	@b swi_Invalid
	
	@ Do nothing for release builds
	bx lr
@---------------------------------------------------------------------------------