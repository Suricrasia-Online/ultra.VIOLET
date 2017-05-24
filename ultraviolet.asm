; shamelessly adapted from the 32-bit version at http://www.muppetlabs.com/~breadbox/software/tiny/teensy.html
BITS 64

		org	 0x00400000

%include "syscalls.asm"

;2 bytes smaller than mov!
%macro  minimov 2
	push %2
	pop %1
%endmacro

ehdr:									; Elf64_Ehdr
		db	0x7F, "ELF", 2, 1, 1, 0		; e_ident

;hide this shit in the padding lmao
__padding:
		minimov rax, sys_close
		minimov rdi, 2
		jmp __uh3

		dw	2							; e_type
		dw	0x3e						; e_machine
		dd	1							; e_version
		dq	__padding						; e_entry
		dq	phdr - $$					; e_phoff
		dq	0							; e_shoff
		dd	0							; e_flags
		dw	ehdrsize					; e_ehsize
		dw	phdrsize					; e_phentsize
		; dw	1							; e_phnum
		; dw	0							; e_shentsize
		; dw	0							; e_shnum
		; dw	0							; e_shstrndx

ehdrsize	equ	 $ - ehdr

phdr:									; Elf64_Phdr
		dd	1							; p_type
__uh3: ;p_flags is supposed to be 0x0f, and syscall is 0x0f05, so I can put code here!
		syscall
		jmp __uh
		; dd	0xf							; p_flags

		dq	0							; p_offset
		dq	$$							; p_vaddr

__uh: ;apparently p_paddr can be nonsense?
		push rax
		; pipe with fds on stack
		minimov rax, sys_pipe
		minimov rdi, rsp
		jmp _start

		; dq	$$							; p_paddr
		dq	filesize					; p_filesz
		dq	filesize					; p_memsz
		dq	0x10						; p_align

phdrsize	equ	 $ - phdr

__tag:

	db "blackle" ;it's me!

_start:
		syscall

		; fork 
		minimov rax, sys_fork
		syscall
		pop	rdi
		test rax,rax
		jz __parent

__child:
		;dup2 read->stdin
		minimov rax, sys_dup2
		; pop	rdi
		; xor rsi,rsi
		syscall

		;close the write end
		; apparently we don't need this as parent?
		; minimov rax, sys_close
		; shr rdi, 32
		; syscall

		; envp -> rdx
		; pop rdx ;argc
		; inc rdx ;argc + 1
		; shl rdx, 3 ; (argc+1)*8

		; assume argc = 1
		minimov rdx, 16+8
		add rdx,rsp

		;setup argv
		push 0
		push __aplay

		; call aplay
		minimov rax, sys_execve
		minimov	rdi, __aplay
		minimov	rsi, rsp
		syscall

	; anything can go here

__parent:
		;get pipe write fd
		shr rdi, 32

		; xor r15, r15
__reset:
		xor r14, r14
__sampleloop:
		inc r14
		
		push r15
		xor r13, r14
		shr r13, 1

		cmp r14w, 1024*2
		ja __noror
		; xor r13, r14
		bswap r15
		not r15

		cmp r14w, 512
		ja __noror
		; dec r13
		bswap r13d

__noror:
		xor r15, r13
		ror r15, 8
		not r15


		cmp r14w, 1024*8
		jnz __sampleloop

		minimov rsi, rsp
		minimov rdx, 1024*8*8
		minimov rax, sys_write
		; minimov rdi, 1
		syscall

		sub rsp, rdx
		jmp __reset

__aplay:
		db '/usr/bin/aplay';,0,0 ;<-- these last two could be removed

__end_of_file:

filesize	equ	$ - $$
