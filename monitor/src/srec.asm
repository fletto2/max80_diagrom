; S-records over channel A. L keeps up with a host that sends with no
; pauses and no flow control: nothing is shown or sent while it runs, and
; a line is decoded as it comes, so only the copy at its end takes time.
; At 9600 a byte comes every 1 ms, and the SIO holds 3.

; A byte from channel A, with the block anywhere. Keeps BC, DE, HL.
rdch:	push	hl
rc1:	ld	a,(blkhi)
	or	high (SIOCA-BLK)
	ld	h,a
	ld	l,low SIOCA
	ld	a,(hl)
	rrca
	jr	c,rc2
	call	brkk
	jr	rc1
rc2:	ld	l,low SIODA
	ld	a,(hl)
	pop	hl
	cp	1Bh
	jp	z,stop
	cp	3
	jp	z,stop
	ret

; A = two hex digits from channel A, added to lsum. Keeps B, DE, HL.
rdbyte:	call	rdch
	call	hexv
	jp	c,lbad
	add	a,a
	add	a,a
	add	a,a
	add	a,a
	ld	c,a
	call	rdch
	call	hexv
	jp	c,lbad
	or	c
	ld	c,a
	ld	a,(lsum)
	add	a,c
	ld	(lsum),a
	ld	a,c
	ret

; Waits until channel A has been quiet for about 40 ms, so that the rest
; of a file is not taken for commands, or 8K bytes have gone by: a sender
; that never stops, or noise, does not hang the monitor. Keeps BC.
drain:	push	bc
	ld	bc,8192
dr0:	ld	de,5000
dr1:	ld	a,(SIOCA)
	rrca
	jr	nc,dr2
	ld	a,(SIODA)
	dec	bc
	ld	a,b
	or	c
	jr	nz,dr0
	pop	bc
	ret
dr2:	dec	de
	ld	a,d
	or	e
	jr	nz,dr1
	pop	bc
	ret

cL:	call	endl
	call	print
	db	"Send the S-records on channel A. ESC or BREAK stops.",0
	call	crlf
	ld	a,1
	ld	(inload),a
	ld	hl,0
	ld	(lcount),hl
	xor	a
	ld	(gohas),a
	ld	(lfirst),a

; Before the first record anything is skipped, a banner, and an S with
; no type digit after it is a word in it. After the first only blanks
; and line ends: a lost S, or a lost byte of one, stops the load at that
; line, where the rest of a record was taken for text
cl1:	call	rdch
	ld	c,a
	and	0DFh
	cp	'S'
	jr	z,cl1s
	ld	a,(lfirst)
	or	a
	jr	z,cl1
	ld	a,c
	cp	0Dh
	jr	z,cl1
	cp	0Ah
	jr	z,cl1
	cp	' '
	jr	z,cl1
	cp	9
	jr	z,cl1
	or	a
	jr	z,cl1
	jr	clbad
cl1s:	call	rdch
	ld	(ltype),a
	sub	'0'
	cp	10
	jr	c,cl1r
	ld	a,(lfirst)
	or	a
	jr	z,cl1
clbad:	ld	hl,(lcount)
	inc	hl
	ld	(lcount),hl
	jp	lbad
cl1r:	ld	a,1
	ld	(lfirst),a
	ld	hl,(lcount)
	inc	hl
	ld	(lcount),hl
	xor	a
	ld	(lsum),a
	call	rdbyte
	or	a
	jp	z,lbad
	ld	b,a
	ld	e,a			; the record's count
	ld	hl,BUF
cl2:	call	rdbyte
	ld	(hl),a
	inc	hl
	djnz	cl2
	ld	a,(lsum)
	inc	a
	jp	nz,lbad
	ld	d,0
	ld	a,(ltype)
	cp	'1'
	jr	z,cl10
	cp	'2'
	jr	z,cl20
	cp	'9'
	jp	z,cl90
	cp	'8'
	jp	z,cl80
	cp	'0'
	jp	z,cl1
	cp	'5'
	jp	z,cl1
	cp	'6'
	jp	z,cl1
	call	lline
	db	"not a record L takes.",0

; S1: a Z80 address, not in the block
cl10:	ld	a,e
	sub	3
	jp	c,lbad
	jp	z,cl1
	ld	l,a
	ld	h,0
	ld	(lnum),hl
	ld	(rlen),hl
	ld	a,(BUF+1)
	ld	(refc+1),a
	ld	a,(BUF)
	ld	(refc+2),a
	ld	a,0FFh
	ld	(refc),a
	ld	hl,BUF+2
	ld	(lptr),hl
	ld	hl,(refc+1)
	ld	de,(rlen)
	add	hl,de
	jp	c,lrange
	ld	de,BLK+1
	or	a
	sbc	hl,de
	jp	nc,lrange
	call	lwrite
	jp	cl1

; S2: 00000h-1FFFFh are the four chunks in order. A line can cross from
; one to the next.
cl20:	ld	a,e
	sub	4
	jp	c,lbad
	jp	z,cl1
	ld	l,a
	ld	h,0
	ld	(lnum),hl
	ld	hl,BUF+3
	ld	(lptr),hl
	ld	a,(BUF)
	cp	2
	jp	nc,lrange
	ld	h,a
	ld	a,(BUF+1)
	ld	l,a
	add	hl,hl
	ld	a,h			; the chunk
	ld	(refc),a
	ld	a,(BUF+2)
	ld	(refc+1),a
	ld	a,(BUF+1)
	and	7Fh
	ld	(refc+2),a
cl22:	ld	a,(refc)
	ld	hl,nchunk
	cp	(hl)
	jp	nc,lrange
	ld	hl,8000h		; the room left in this chunk
	ld	de,(refc+1)
	or	a
	sbc	hl,de
	ld	de,(lnum)
	ex	de,hl			; HL = the bytes, DE = the room
	call	minde			; HL = what goes here
	ld	(rlen),hl
	ld	de,(lnum)
	ex	de,hl
	or	a
	sbc	hl,de
	ld	(lnum),hl		; what is left after
	call	lwrite
	ld	hl,(lnum)
	ld	a,h
	or	l
	jp	z,cl1
	ld	hl,refc
	inc	(hl)
	ld	hl,0
	ld	(refc+1),hl
	jr	cl22

; rlen bytes from lptr to refc, not over the monitor. lptr moves on.
lwrite:	ld	ix,refc
	call	over
	jp	c,lmon
	ld	bc,(rlen)
	ld	hl,(lptr)
	call	putp
	ld	hl,(lptr)
	ld	bc,(rlen)
	add	hl,bc
	ld	(lptr),hl
	ret

; S9 and S8: the end, and the start for G
cl90:	ld	a,e			; 2 address bytes and the sum
	cp	3
	jp	c,lbad
	ld	a,(BUF)
	ld	h,a
	ld	a,(BUF+1)
	ld	l,a
	ld	(goaddr),hl
	ld	a,0FFh
	ld	(gochunk),a
	ld	a,h
	or	l
	jr	cl95
cl80:	ld	a,e			; 3 address bytes and the sum
	cp	4
	jp	c,lbad
	ld	a,(BUF)
	cp	2
	jp	nc,lrange
	ld	h,a
	ld	a,(BUF+1)
	ld	l,a
	add	hl,hl
	ld	a,h
	ld	hl,nchunk		; a chunk that is there, as for S2
	cp	(hl)
	jp	nc,lrange
	ld	(gochunk),a
	ld	a,(BUF+1)
	and	7Fh
	ld	h,a
	ld	a,(BUF+2)
	ld	l,a
	ld	(goaddr),hl
	ld	a,(BUF)
	ld	c,a
	ld	a,(BUF+1)
	or	c
	ld	c,a
	ld	a,(BUF+2)
	or	c
cl95:	ld	(gohas),a
	call	mnorm
	call	drain
	call	print
	db	"Loaded ",0
	ld	hl,(lcount)
	call	pdec16
	call	print
	db	" lines.",0
	ld	a,(gohas)
	or	a
	jr	z,cl98
	call	print
	db	" Start ",0
	ld	a,(gochunk)
	ld	(rtmp),a
	ld	hl,(goaddr)
	ld	(rtmp+1),hl
	ld	ix,rtmp
	call	pref
	ld	a,'.'
	call	putc
cl98:	call	crlf
	jp	cmd

lbad:	call	lline
	db	"bad record or checksum.",0
lrange:	call	lline
	db	"that address cannot be loaded.",0
lmon:	call	lline
	db	"the monitor is there.",0

; Line lcount and the message after the call, once the host has stopped
lline:	call	mnorm
	call	drain
	call	print
	db	"Line ",0
	ld	hl,(lcount)
	call	pdec16
	call	print
	db	": ",0
	pop	hl
	call	puts
	call	crlf
	jp	cmd

; A byte of a record, as two digits, added to psum
pbyte:	push	af
	push	bc
	ld	c,a
	ld	a,(psum)
	add	a,c
	ld	(psum),a
	ld	a,c
	rrca
	rrca
	rrca
	rrca
	call	pdig4
	ld	a,c
	call	pdig4
	pop	bc
	pop	af
	ret
pdig4:	and	0Fh
	add	a,90h
	daa
	adc	a,40h
	daa
	jp	sout

; P addr len: 32 bytes a line, S1 and an S9, or S2 and an S8 for a chunk
; address. To channel A alone.
cP:	call	getaddr
	call	getlen
	call	endl
	call	chkrng
	call	blkask
	ld	a,1
	ld	(sioon),a
cp1:	ld	de,32
	call	nextd
	jp	z,cp5
	ld	(pn),bc
	ld	de,BUF
	call	getp
	call	mnorm			; sent with the block at F000h: no
	xor	a			; serial write in a chunk read
	ld	(psum),a
	ld	a,'S'
	call	sout
	ld	a,(ix+0)
	inc	a
	ld	c,3			; the count past the data
	ld	a,'1'
	jr	z,cp2
	inc	c
	inc	a
cp2:	call	sout
	ld	a,(pn)
	add	a,c
	call	pbyte
	ld	a,(ix+0)
	inc	a
	jr	z,cp3
	dec	a
	rrca				; the 24-bit address
	push	af
	and	1
	call	pbyte
	pop	af
	and	80h
	or	(ix+2)
	jr	cp4
cp3:	ld	a,(ix+2)
cp4:	call	pbyte
	ld	a,(ix+1)
	call	pbyte
	ld	hl,BUF
	ld	a,(pn)
	ld	b,a
cp41:	ld	a,(hl)
	inc	hl
	call	pbyte
	djnz	cp41
	ld	a,(psum)
	cpl
	call	pbyte
	call	pend
	ld	bc,(pn)
	call	adv
	ld	a,(sioon)
	or	a
	jr	nz,cp1
	ld	a,1
	ld	(sioon),a
	call	eprint
	db	"Channel A does not send.",0
cp5:	ld	hl,s9rec
	ld	a,(ix+0)
	inc	a
	jr	z,cp6
	ld	hl,s8rec
cp6:	ld	a,(hl)
	inc	hl
	or	a
	jr	z,cp7
	call	sout
	jr	cp6
cp7:	call	pend
	call	eprint
	db	"Punched.",0

pend:	ld	a,0Dh
	call	sout
	ld	a,0Ah
	jp	sout

s9rec:	db	"S9030000FC",0
s8rec:	db	"S804000000FB",0
