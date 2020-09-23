;*****************************************************************************************
;** GDIplusSafeToken.asm - subclassing thunk. Assemble with nasm.
;*****************************************************************************************

;***************
;API definitions
M_RELEASE		equ	dword 8000h	    ;VirtualFree memory release flag
WM_Destroy		equ	dword 2h	    ;Window being destroyed
WM_Close		equ	dword 10h       ;Window is closing
GWL_WndProc		equ	dword -4        ;Window Procedure

;******************************
;Stack frame access definitions
%define lParam          [ebp + 48]  ;WndProc lParam
%define wParam          [ebp + 44]  ;WndProc wParam
%define uMsg            [ebp + 40]  ;WndProc uMsg
%define hWnd            [ebp + 36]  ;WndProc hWnd
%define lRetAddr        [ebp + 32]  ;Return address of the code that called us
%define lReturn         [ebp + 28]  ;lReturn local, restored to eax after popad
%define lVirtFreeHack	[ebp + 20]  ;See _releaseMemory below

;***********************
;Data access definitions
%define nRecursion	[ebx + 0]   ;recursion counter
%define bShutdown       [ebx + 4]  	;Shutdown flag
%define fnCallWindProc  [ebx + 8]  ;CallWindowProc function address
%define fnVirtualFree   [ebx + 12]  ;VirtualFree function address
%define fnFreeLib		[ebx + 16]	;FreeLibrary function address
%define gdiToken        [ebx + 20]  ;gdi+ token
%define fnGDIpShutdown  [ebx + 24]	;PostMessage function address
%define fnSetWinLong    [ebx + 28]	;SetWindowLong function address
%define fnSetTimer	[ebx + 32]	;SetTimer function address
%define fnKillTimer	[ebx + 36]	;KillTimer function address
%define hGDIplus		[ebx + 40]  ;handle to GDI+ library
%define addrWndProc	[ebx + 44]	;previous window procedure

use32
;************
;Data storage				;see above for description
    dd_nRecursion		dd 0
    dd_bShutdown		dd 0	    
    dd_fnCallWindProc   dd 0	    
    dd_fnVirtualFree    dd 0	    
    dd_FreeLib		dd 0
    dd_gdiToken         dd 0	    
    dd_fnGDIpShutdown	dd 0	
    dd_fnSetWinLong	dd 0	
    dd_fnSetTimer		dd 0
    dd_fnKillTimer	dd 0	
    dd_hGDIplus		dd 0
    dd_addrWndProc	dd 0

    
;***********
;Thunk start    
    xor     eax, eax		    	;Zero eax, lReturn in the ebp stack frame
    xor     edx, edx		    	;Zero edx, bHandled in the ebp stack frame
    pushad			    		;Push all the cpu registers on to the stack
    mov     ebp, esp		    	;Setup the ebp stack frame
    mov     ebx, 012345678h	    	;dummy Address of the data, patched from VB
 
    xor     esi, esi		    	;Zero esi
    inc     dword nRecursion	    	;Increment the WndProc call counter

Align 4
_wndproc:
    cmp	hWnd, esi			;hWnd=0?  If so, from our timer
    jz	_releaseToken		;we're done, release token & thunk memmory

    push    dword lParam	    	;ByVal lParam
    push    dword wParam	    	;ByVal wParam
    push    dword uMsg		    	;ByVal uMsg
    push    dword hWnd		    	;ByVal hWnd
    push	dword addrWndProc		;prev window procedure
    call    near fnCallWindProc   	;CallWindowProc
    mov     lReturn, eax	    	;Save the return value

    dec     dword nRecursion	    	;Decrement the WndProc call counter
    cmp	uMsg, dword WM_Destroy 	;is this a WM_Destroy message?
    jnz	_checkRecursion		
    mov	bShutdown, dword 2	;shutdown by user call or our PostMessage above

Align 4
_checkRecursion:
    cmp	nRecursion, esi		;are we done recursing?
    jnz	_return			;nope, just return
    cmp	bShutdown, dword 2	;are we ready to release token and/or memory?
    jnz	_return			;nope, continue on. Else ...

    push    dword addrWndProc		;unsubclass window
    push    dword GWL_WndProc
    push    dword hWnd
    call	fnSetWinLong	
    
    push 	dword 012345678h		;patched from VB. "Thunk Start" address
    push	dword 50			;50 ms timer
    push	esi    			;no timerID, windows sets it
    push	esi				;set windowless callback timer
    call	fnSetTimer			; set the timer
    mov	fnSetTimer, eax		; cache the timerID returned 

Align 4
_return:
    popad			    		;Pop all registers. lReturn is popped into eax
    ret     16			    	;Return with a 16 byte stack release

_releaseToken:
    push	dword fnSetTimer		;our timer fired; kill it
    push	esi			
    call	fnKillTimer

    push    dword gdiToken		
    call	fnGDIpShutdown		;Destroy GDI+ token

    push	dword hGDIplus		;free GDI+ library
    call	fnFreeLib

_releaseMemory:
    pop     eax 		    		;Eat the call return address
    mov     uMsg, ebx		    	;VirtualFree param #1, start address of this memory
    mov     wParam, esi 	    	;VirtualFree param #2, 0
    mov     lParam, dword M_RELEASE ;VirtualFree param #3, memory release flag
    mov     eax, lRetAddr	    	;Return address of the code that called this thunk
    mov     lVirtFreeHack, ebx    	;ebx popped to edx after the popad instruction
    mov     hWnd, eax		    	;Return address to the code that called this thunk
    popad			    		;Restore the registers
    add     esp, 4		    	;Adjust the stack to point to the new return address
    jmp     dword fnVirtualFree     ;Jump to VirtualFree, ret to the caller of this thunk
