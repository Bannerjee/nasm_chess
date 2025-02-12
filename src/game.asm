bits 64
default rel

%define GAME_ASM
%include "src/macroses.mac"
global checkMove
section .data:
	offs dd 0.0625 ; offset inside texture atlas
	one dd 1.0
	n8 dd -8.0
	xmin dd 1.3
	xmax dd 4.8
	ymin dd 0.8
section .text
extern DialogBoxParamA
;(unsigned char* array,char turn,int se,DLGPROC func)
checkMove:
	push   rbx
	sub    rsp, 32
	
	xor    eax, eax
	mov    r11, rcx
	mov    ecx, edx
	mov    edx, r8d
	movzx  r8d, r8w
	sar    edx, 16
	cmp    edx, r8d
	je     .fin
	movsxd rdx, edx
	mov    r10b, byte[r11+rdx*1]
	test   r10b, r10b
	je     .fin
	test   cl, 2
	je     .j56
	cmp    r10b, 0x6
	jbe    .j84
	jmp    .fin
.j56:
	xor    eax, eax
	cmp    r10b, 0x6
	jbe    .fin
	movsxd rbx, r8d
	cmp    byte[r11+rbx*1], 6
	ja     .fin
	sar    r8d, 3
	cmp    r10b, 7
	jmp    .j111
.j84:
	movsxd rax, r8d
	mov    r11b, byte[r11+rax*1]
	cmp    r11b, 6
	ja     .j104
	xor    eax,eax
	test   r11b,r11b
	jne    .fin
.j104:
	sar    r8d,3
	dec    r10b
.j111:
	je     .j117
.j113:
	mov    al,1
	jmp    .fin
.j117:
	cmp    r8d,7
	jne    .j130
	and    cl,1
	je		.j135
	jmp		.j140
.j130:
	and		cl,0x1
	jne		.j113
.j135:
	test	r8d,r8d
	jne		.j113
.j140:
	mov		QWORD [rsp+0x20],rdx
	xor		r8d,r8d
	xor		ecx,ecx
	mov		rdx, 106
	call	DialogBoxParamA
	jmp		.j113
.fin:
	add		rsp,32
	pop		rbx
	ret
	;int start = se >> 16;
    ;int end = se & 0xFFFF;
    ;if (start == end || !array[start]) return false; // cannot move empty cell or stay at the same one

   ; char color = turn & 0b10;
   ; char isBottomPlayer = turn & 0b01;
   ; if ((color && array[start] > 6) || (!color && array[start] < 7)) return false; // order of turns

   ; if ((array[start] > 6 && array[end] > 6) || (array[start] < 7 && array[start] > 0 && array[end] < 7 && array[end] > 0)) return false; // friendly fire

    ;int eRow = end / 8;
    ;if (array[start] == B_PAWN || array[start] == W_PAWN) {
     ;   if ((isBottomPlayer && eRow == 7) || (!isBottomPlayer && eRow == 0)) {
      ;      DialogBoxParamA(0, MAKEINTRESOURCE(PROMOTE_PAWN), 0, func, start);
      ;  }
    ;}
    ;return true;
; rcx - lParam
; rdx - HWND
; returns cell in array calculated from mouse coords in lParam
CoordsToCell:
	prologue SHADOW_SPACE + 16
	push rsi
	mov rsi, rcx
	
	mov rcx, rdx
	lea rdx, [rbp - 32]
	call GetClientRect
	
	xor r9, r9
	xor r10,r10
	mov r9, rsi
	LOWORD r9
	mov r10, rsi
	HIWORD r10
	
	xor edx,edx
	mov eax, dword[rbp - 24]; right
	mov ecx, 8
	div ecx
	mov ecx, eax
	xor edx, edx
	mov eax, r9d
	div ecx
	mov r8d, eax ; x
	
	xor edx, edx
	mov eax, dword[rbp - 20]; bottom
	mov ecx, 8
	div ecx
	mov ecx, eax
	xor edx, edx
	mov eax, r10d
	div ecx ; eax = y
	
	mov ecx, 7
	sub ecx, eax
	imul ecx, 8
	add ecx, r8d
	mov eax, ecx

	;;imul eax, 8
	;;add eax, r8d
	
	pop rsi
	epilogue SHADOW_SPACE  + 16

; ecx - x
; edx - y
; r8d - figure
; r9d - atlas
renderTile:
	prologue SHADOW_SPACE + 112
	movaps [rbp - 16], xmm6
	movaps [rbp - 32], xmm7
	movaps [rbp -  48], xmm8
	movaps [rbp -  64], xmm9
	movaps [rbp -  80], xmm10
	movaps [rbp - 112], xmm11
	
	test r8d, r8d
	je .end
	
	imul ecx, 6
	imul edx, 6
	cvtsi2ss xmm6, r8d
	mulss xmm6, dword[offs]
	movss xmm7, dword[offs]
	addss xmm7, xmm6
	
	cvtsi2ss xmm8, ecx ; x1
	cvtsi2ss xmm9, edx ; y1
	
	movss xmm10, xmm8 ; x2
	movss xmm11, xmm9 ; y2
	
	addss xmm8, dword[xmin]
	addss xmm9, dword[ymin]
	addss xmm10,dword[xmax]
	addss xmm11, dword[xmax]
	addss xmm11, dword[ymin]
	
	bindTexture GL_TEXTURE_2D, r9d
	
	beginRendering GL_QUADS
	
	movaps xmm0, xmm6
	xorps xmm1,xmm1
	call glTexCoord2f
	
	movaps xmm0, xmm8
	movaps xmm1, xmm11
	movss xmm2, dword[n8]
	call glVertex3f
	
	movaps xmm0, xmm7
	xorps xmm1,xmm1
	call glTexCoord2f
	
	movaps xmm0, xmm10
	movaps xmm1, xmm11
	movss xmm2, dword[n8]
	call glVertex3f
	
	movaps xmm0, xmm7
	movss xmm1, dword[one]
	call glTexCoord2f
	
	movaps xmm0, xmm10
	movaps xmm1, xmm9
	movss xmm2, dword[n8]
	call glVertex3f
	
	movaps xmm0, xmm6 
	movss xmm1, dword[one]
	call glTexCoord2f
	
	movaps xmm0, xmm8
	movaps xmm1, xmm9
	movss xmm2, dword[n8]
	call glVertex3f
	
	endRendering
.end:
	movaps xmm6 , [rbp - 16]
	movaps xmm7 , [rbp - 32]
	movaps xmm8 , [rbp - 48]
	movaps xmm9 , [rbp - 64]
	movaps xmm10, [rbp - 80]
	movaps xmm11, [rbp - 112]
	epilogue SHADOW_SPACE + 112

placeFigures:
	prologue SHADOW_SPACE
	push rsi
	push rdi
	mov ecx, 64
	call malloc
	mov rsi, rax
	
	xor ecx, ecx
	mov edx, 1
	call prng
	mov edi, eax
	
	mov rcx, rsi
	mov edx, EMPTY
	mov r8d, 64
	call memset ; clear board
	
	mov rcx, rsi
	add rcx, 8
	mov edx, B_PAWN 
	test edi, edi
	mov eax, W_PAWN
	cmove edx, eax
	mov r8d, 8
	call memset ; set pawns
	
	mov rcx, rsi
	add rcx, 48
	mov edx, W_PAWN 
	test edi, edi
	mov eax, B_PAWN
	cmove edx, eax
	mov r8d, 8
	call memset ; set pawns

	mov byte[rbp - 16], B_ROOK
	mov byte[rbp - 15], B_KNIGHT
	mov byte[rbp - 14], B_BISHOP
	mov byte[rbp - 13], B_QUEEN
	mov byte[rbp - 12], B_KING
	mov byte[rbp - 11], B_BISHOP
	mov byte[rbp - 10], B_KNIGHT
	mov byte[rbp -  9], B_ROOK
	
	mov byte[rbp -  8], W_ROOK
	mov byte[rbp -  7], W_KNIGHT
	mov byte[rbp -  6], W_BISHOP
	mov byte[rbp -  5], W_QUEEN
	mov byte[rbp -  4], W_KING
	mov byte[rbp -  3], W_BISHOP
	mov byte[rbp -  2], W_KNIGHT
	mov byte[rbp -  1], W_ROOK
	
	lea rdx, [rbp - 16]
	lea rcx, [rbp - 8]
	test edi, edi
	cmove rdx, rcx
	mov rcx, rsi
	mov r8d, 8
	call memcpy
	
	lea rdx, [rbp - 8]
	lea rcx, [rbp - 16]
	test edi, edi
	cmove rdx, rcx
	mov rcx, rsi
	add rcx, 56
	mov r8d, 8
	call memcpy
	
	mov rax, rsi
	pop rdi
	pop rsi
	epilogue SHADOW_SPACE
; ecx - start of range
; edx - end of range
; returns pseudo random number in range from ecx to edx
prng:
	prologue SHADOW_SPACE
	
	sub edx, ecx
	movsxd r9, edx
	inc r9
	xor rdx, rdx
	rdrand rax
	mov r8 , rax
	sar r8 , 12 
	xor rax, r8 ; rax ^= rax >> 12
	
	mov r8 , rax
	sar r8 , 25
	xor rax, r8 ; rax ^= rax >> 25
	
	mov r8 , rax
	sar r8 , 27
	xor rax, r8 ; rax ^= rax >> 27
	
	mov r8, 0x2545F4914F6CDD1D
	imul rax, r8
	div r9
	add edx, ecx
	mov eax, edx ; return ecx + (rax * 0x2545F4914F6CDD1D % (edx-ecx + 1))
	epilogue SHADOW_SPACE
createBoard:
	prologue SHADOW_SPACE + 56
	push rsi
	push rdi
	push rbx
	mov ecx, 192
	call   malloc
	mov qword[rbp - 8], rax

	lea rsi, [rbp -  18] ; black square
	lea rdi, [rbp - 21]  ; white square
	
	mov byte[rbp -  16], 121
	mov byte[rbp -  17], 72
	mov byte[rbp -  18], 57
	
	mov byte[rbp -  19], 93
	mov byte[rbp -  20], 50
	mov byte[rbp -  21], 49

	xor rbx, rbx
.loop:
	mov rax, rbx
	xor rdx, rdx
	mov rcx, 8
	div rcx
	add rax, rdx
	mov rdx, rsi
	test rax, 1
	cmove  rdx, rdi
	mov rcx, qword[rbp - 8]
	imul rax, rbx, 3
	add rcx, rax
	mov r8d, 3
	call memcpy ; memcpy(&data[rbx*3],(rbx / 8 + rbx % 8) % 2 == 0 ? black : white,3);

	inc rbx
	cmp rbx, 64
	jne .loop
	
	mov ecx, 524296 ; 8 << 16 | 8
	mov edx, 206336 ; 3 << 16 | GL_NEAREST
	mov r8d, GL_RGB
	mov r9, qword[rbp - 8]
	call createTexture
	mov rcx, qword[rbp - 8]
	mov esi, eax
	call free
	mov eax,esi
	pop rbx
	pop rdi
	pop rsi
	epilogue SHADOW_SPACE + 56

; ecx - width << 16 | height
; edx - channels << 16 | filter
; r8d - format
; r9  - raw image bytes ptr
; returns texture handle
createTexture:
	prologue SHADOW_SPACE + 48
	
	mov dword[rbp + 16], ecx
	mov dword[rbp + 24], edx
	mov dword[rbp + 32], r8d
	mov qword[rbp + 40], r9
	
	mov ecx, 1
	lea rdx,[rbp - 4]
	call glGenTextures ; glGenTextures(1,&tex);
	
	bindTexture GL_TEXTURE_2D,dword[rbp - 4]
	
	texParameteri GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR
	
	mov eax, dword[rbp + 24]
	movzx eax, ax
	mov r8d,eax
	texParameteri GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,eax
;  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, edx & 0xFFFF);
	
	mov ecx, GL_TEXTURE_2D
	mov edx, 0
	mov r8d, dword[rbp + 24]
	sar r8d, 16
	mov r9d, dword[rbp + 16]
	sar r9d, 16
	mov eax, dword[rbp + 16]
	movzx eax, ax
	mov dword[rsp + 4 * 8], eax
	mov dword[rsp + 5 * 8], 0
	mov eax, dword[rbp + 32]
	mov dword[rsp + 6 * 8], eax
	mov dword[rsp + 7 * 8], GL_UNSIGNED_BYTE
	mov rax, qword[rbp + 40]
	mov qword[rsp + 8 * 8], rax
	call glTexImage2D  ; glTexImage2D(GL_TEXTURE_2D, 0, edx >> 16, ecx >> 16, ecx & 0xFFFF, 0, r8d,GL_UNSIGNED_BYTE, r9);
	mov eax, dword[rbp - 4]
	epilogue SHADOW_SPACE + 48
