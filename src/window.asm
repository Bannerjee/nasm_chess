bits 64
default rel

%define WINDOW_ASM
%include "src/macroses.mac"

section .data
    rb   db 'rb', 0

section .text
extern FindResourceA
extern LoadResource
extern LockResource
extern GdiplusShutdown
extern GdiplusStartup
extern GdipBitmapLockBits
extern GdipBitmapUnlockBits
extern FindResourceA
extern SizeofResource
extern LoadResource
extern LockResource
extern GdipGetImageWidth
extern GdipGetImageHeight
extern GdipCreateBitmapFromStream
extern SHCreateMemStream
extern GdiplusRect
global loadPNG
; ecx - resource id
; loads cursor from resource
loadCur:
	sub rsp, 48
	push rbx
	mov ebx,ecx
	xor ecx,ecx
	call GetModuleHandleA
	mov rcx, rax
	movzx edx, bx
	mov r8d, 1
	xor r9d, r9d
	mov dword[rsp + 4 * 8], 0
	mov dword[rsp + 5 * 8], 0x8040
	call LoadImageA ; LoadImageA(GetModuleHandleA(0),MAKEINTRESOURCE(id),IMAGE_ICON,0,0, LR_DEFAULTSIZE | LR_SHARED)
	pop rbx
	add rsp, 48
	ret
	
loadPNG:
push   r12
push   rbp
push   rdi
push   rsi
push   rbx
sub    rsp,0x90
mov    rbp,rdx
mov    rbx,r8
lea    rdx,[rsp+0x58]
mov    esi,ecx
xor    r8d,r8d
lea    rcx,[rsp+0x38]
mov    QWORD  [rsp+0x58],0x1
and    QWORD  [rsp+0x60],0x0
and    QWORD  [rsp+0x68],0x0
call   GdiplusStartup
push   0xa
movzx  edx,si
pop    r8
xor    ecx,ecx
call   FindResourceA
xor    ecx,ecx
xchg   rsi,rax
mov    rdx,rsi
call	SizeofResource
mov    rdx,rsi
xor    ecx,ecx
xchg   r12d,eax
call   LoadResource
xchg   rcx,rax
call   LockResource
mov    edx,r12d
lea    r12,[rsp+0x70]
xchg   rcx,rax
call   SHCreateMemStream
lea    rdx,[rsp+0x40]
xchg   rsi,rax
mov    rcx,rsi
call   GdipCreateBitmapFromStream
mov    rax,QWORD [rsi]
mov    rcx,rsi
call   QWORD [rax+0x10]
mov    rcx,QWORD  [rsp+0x40]
mov    rdx,rbp
call   GdipGetImageWidth
mov    rcx,QWORD  [rsp+0x40]
mov    rdx,rbx
call   GdipGetImageHeight
mov    eax,DWORD  [rbp+0x0]
lea    rdx,[rsp+0x48]
and    QWORD  [rsp+0x48],0x0
mov    r9d,0x26200a
mov    DWORD  [rsp+0x50],eax
mov    eax,DWORD  [rbx]
mov    QWORD  [rsp+0x20],r12
mov    DWORD  [rsp+0x54],eax
push   0x1
pop    r8
mov    rcx,QWORD  [rsp+0x40]
call   GdipBitmapLockBits
mov    eax,DWORD  [rbp+0x0]
imul   eax,DWORD  [rbx]
lea    ebp,[rax*4+0x0]
mov    rcx,rbp
call   malloc
mov    rsi,QWORD  [rsp+0x80]
mov    rcx,rbp
mov    rdx,r12
xchg   rbx,rax
mov    rdi,rbx
;rep movs BYTE PTR es:[rdi],BYTE PTR ds:[rsi]
mov    rcx,QWORD  [rsp+0x40]
call   GdipBitmapUnlockBits
mov    rcx,QWORD  [rsp+0x38]
call   GdiplusShutdown
xchg   rbx,rax
add    rsp,0x90
pop    rbx
pop    rsi
pop    rdi
pop    rbp
pop    r12
ret
nop
nop
; rcx - hwnd
; rdx - hdc ref
; r8d - flags
;returns HGLRC
createContext:
	prologue SHADOW_SPACE + 48
	
	mov qword[rbp + 16], rcx
	mov qword[rbp + 24], rdx
	mov dword[rbp + 32], r8d
	
	zeroOut rbp - 48, 40
	mov word [rbp - 48], 40
	mov word [rbp - 46], 1
	mov r8d,dword[rbp + 32]
	mov dword[rbp - 44], r8d
	mov byte [rbp - 39], 32
	mov byte [rbp - 25], 24
	mov byte [rbp - 24], 8
	
	lea r9,[rbp - 48]
	mov qword[rbp + 32],r9 ; rbp + 32 now contains ptr to PIXELFORMATDESCRIPTOR
	
	mov rcx, qword[rbp + 16]
	call GetDC ; GetDC(rcx)
	
	mov rdx, qword[rbp + 24]
	mov qword[rdx], rax
	
	mov rcx, rax
	mov rdx, qword[rbp + 32]
	call ChoosePixelFormat ; ChoosePixelFormat(rdx,r8d);
	
	mov rcx, qword[rbp + 24]
	mov rcx, [rcx]
	mov edx, eax
	mov r8, qword[rbp + 32]
	call SetPixelFormat ; SetPixelFormat(rdx,pxFormat,rbp + 32);
	
	
	mov rcx, qword[rbp + 24]
	mov rcx, [rcx]
	call wglCreateContext ; wglCreateContext(rdx);
	
	mov qword[rbp - 16],rax
	
	mov rcx, qword [rbp + 24]
	mov rcx, [rcx]
	mov rdx, rax
	call wglMakeCurrent ; wglMakeCurrent(rdx,hglrc);
	
	mov rax,qword[rbp - 16]
	
	epilogue SHADOW_SPACE + 48
	
; rcx - string to hash
; returns uint32_t hashed string
hash:
	prologue SHADOW_SPACE
	xor r8d,r8d 	; storage for resulting hash
	movsx eax, byte[rcx]
	test al,al
	je .end
.loop:
	mov edx, r8d
	imul r8d, 31
	add r8d, eax
	
	add rcx, 1
	movsx eax, byte[rcx]
	test al,al
	jne .loop
.end:
	mov eax,r8d
	epilogue SHADOW_SPACE
	ret
	
; rcx - window title
; rdx - className
; r8  - lpfnWndProc
; r9d - width << 16 | height
; returns HWND to window
ConstructWindow:
	prologue SHADOW_SPACE + 96
	mov qword[rbp + 16], rcx ; title
	mov qword[rbp + 24], rdx ; className
	mov qword[rbp + 32], r8  ; wndproc
	mov dword[rbp - 8],  r9d ; width + height

	xor ecx,ecx
	call GetModuleHandleA 	; get HINSTANCE
	mov qword[rbp - 16],rax	; and save it
	mov r8, rax
	
	mov rcx, qword[rbp + 24]
	mov rdx, qword[rbp + 32]
	call registerClass		 ; obvious
	
	xor ecx, ecx
	mov rdx, qword[rbp + 24]
	mov r8,  qword[rbp + 16]
	mov r9d, 282001408		 ; WS_OVERLAPPEDWINDOW|WS_VISIBLE
	mov eax, dword[rbp - 8]
	sar eax, 16
	mov dword[rsp +  4 * 8], 0
	mov dword[rsp +  5 * 8], 0
	mov dword[rsp +  6 * 8], eax
	sar eax,16
	mov eax,dword[rbp - 8]
	and eax,0xFFFF
	mov dword[rsp +  7 * 8], eax
	mov qword[rsp +  8 * 8], 0
	mov qword[rsp +  9 * 8], 0
	mov rax, qword[rbp - 16]
	mov qword[rsp + 10 * 8], rax
	mov qword[rsp + 11 * 8], 0
	call CreateWindowExA ; CreateWindowExA(0,rdx,rcx,WS_OVERLAPPEDWINDOW|WS_VISIBLE,0,0,r9d >> 16,r9d & 0xFFFF,0,0,HINSTANCE,0);
	
	epilogue SHADOW_SPACE + 96

; rcx - className
; rdx - lpfnWndProc
; r8  - instance
; returns void
registerClass:
	prologue SHADOW_SPACE + 80
	
	mov qword [ rbp + 16 ], rcx
	mov qword [ rbp + 24 ], rdx
	mov qword [ rbp + 32 ], r8
	
	zeroOut rbp - 80,80
	; WNDCLASSEXA struct
	mov dword [ rbp - 80 ], 80  ; cbSize
	mov dword [ rbp - 76 ], 0x0020   ; CS_HREDRAW | CS_VREDRAW | CS_OWNDC
	mov rax,  qword [ rbp + 24 ]
	mov qword [ rbp - 72  ], rax ; lpfnWndProc
	
	mov rax, qword [ rbp + 32 ]
	mov qword [ rbp - 56 ], rax ; hInstance
	
	xor ecx,ecx
	xor edx,edx ; IDC_HAND
	call LoadIconA
	mov qword [ rbp - 48 ], rax ; hCursor
	
	xor ecx,ecx
	mov edx,0x7f00
	call LoadCursorA
	mov qword[ rbp - 40 ], rax
	mov rax, qword[ rbp + 16 ]
	mov qword[ rbp - 16 ],  rax
	

	lea rcx,  [ rbp - 80 ] ; our class
	call RegisterClassExA
	epilogue SHADOW_SPACE + 80
