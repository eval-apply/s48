; Copyright (c) 1993-2007 by Richard Kelsey and Jonathan Rees. See file COPYING.

; Server interface
;   (open-socket [socket-number]) -> socket
;   (close-socket socket)
;   (socket-accept socket) -> [input-port output-port]
;   (get-host-name) -> string
;   (socket-port-number socket) -> integer

; Client interface
;   (socket-client host-name socket-number) -> [input-port output-port]

; (get-host-by-name name) -> address
; (get-host-by-address address) -> name

; Old calls I would like to get rid off.
;   (socket-listen socket) -> [input-port output-port]
;   (socket-listen-channels socket) -> [input-channel output-channel]
;   (socket-client-channels host-name socket-number) -> [input-channels output-channels]

;--------------------
; Socket type
;
; A socket has a channel (for accepting connections) and a port number.
; These are only used for servers and udp sockets; clients don't need them.

(define-record-type socket :socket
  (really-make-socket type channel port-number condvar)
  socket?
  (type        socket-type)	; SOCKET, UPD-INPUT-SOCKET, UDP-OUTPUT-SOCKET
  (channel     socket-channel)
  (port-number socket-port-number)
  (condvar     socket-condvar))	; for blocking until a connection arrives

(define (make-socket type channel)
  (really-make-socket type
		      channel
		      (socket-number channel)
		      (make-condvar)))

(define-record-discloser :socket
  (lambda (s)
    `(,(socket-type s) ,(socket-port-number s))))

; Close the channel, notifying any waiters that this has happened.

(define (close-socket socket)
  (let ((channel (socket-channel socket))
	(close-channel (case (socket-type socket)
			 ((socket)           close-channel)
			 ((udp-input-socket) close-socket-input-channel)
			 (else               close-socket-output-channel))))
    (with-new-proposal (lose)
      (or (channel-maybe-commit-and-close channel close-channel)
	  (lose)))))

; Makes a server socket.

(define (open-socket . maybe-number)
  (let ((channel (new-socket #f #t)))
    (bind-socket channel (if (or (null? maybe-number)
				 (= (car maybe-number) 0))  ; old, crappy spec
			     #f
			     (car maybe-number)))
    (real-socket-listen channel)
    (make-socket 'socket channel)))

(define (socket-accept socket)
  (call-with-values
   (lambda ()
     (socket-listen-channels socket))
   (lambda (in out)
     (values (input-channel+closer->port in close-socket-input-channel)
	     (output-channel+closer->port out close-socket-output-channel)))))
  
(define socket-listen socket-accept)

(define (socket-listen-channels socket)
  (let ((input-channel (blocking-socket-op socket real-socket-accept)))
    (values input-channel
	    (dup-socket-channel input-channel))))

; Keep performing OP until it returns a non-#F value.  In between attempts we
; block on the socket's channel.

(define (blocking-socket-op socket op)
  (let ((channel (socket-channel socket))
	(condvar (socket-condvar socket)))
    (let loop ((retry? #f))
      (disable-interrupts!)
      (cond ((op channel retry?)
	     => (lambda (result)
		  (enable-interrupts!)
		  result))
	    (else
	     (wait-for-channel channel condvar)
	     (with-new-proposal (lose)
	       (maybe-commit-and-wait-for-condvar condvar))
	     (enable-interrupts!)
	     (loop #t))))))

; Connect to the socket and return input and output ports.

(define (socket-client host-name port-number)
  (call-with-values
   (lambda ()
     (socket-client-channels host-name port-number))
   (lambda (in out)
     (values (input-channel+closer->port in close-socket-input-channel)
	     (output-channel+closer->port out close-socket-output-channel)))))

; FreeBSD's connect() behaves oddly.  If you get told to wait, wait for select()
; to signal the all-clear, and then try to connect again, you get an `already
; connected' error.  To handle this we pass in a RETRY? flag.  If RETRY? is
; true the `already connected' error is ignored.

(define (socket-client-channels host-name port-number)
  (let ((channel (new-socket #f #f)))
    (let loop ((retry? #f))
      (disable-interrupts!)
      (let ((output-channel (real-socket-connect channel
						 (get-host-by-name host-name)
						 port-number
						 retry?)))
	(cond ((channel? output-channel)
	       (enable-interrupts!)
	       (values channel output-channel))
	      ((eq? output-channel #t)
	       (assertion-violation 'socket-client
				    "client socket already connected"
				    host-name port-number))
	      (else
	       (let ((condvar (make-condvar)))
		 (wait-for-channel channel condvar)
		 (with-new-proposal (lose)
		   (maybe-commit-and-wait-for-condvar condvar))
		 (enable-interrupts!)
		 (loop #t))))))))

(define (get-host-by-xxx retval get-result)
  (if (pair? retval)
      (let ((result #f))
	(dynamic-wind ; we need to release the uid in case the thread gets killed
	    values
	    (lambda ()
	      (wait-for-external-event (car retval)))
	    (lambda ()
	      (set! result (get-result (cdr retval)))))
	result)
      retval))

(define (get-host-by-name name)
  (get-host-by-xxx (real-get-host-by-name (host-name->byte-vector name))
		   get-host-by-name-result))

(define (get-host-by-address address)
  (get-host-by-xxx (real-get-host-by-address address)
		   get-host-by-address-result))

;; #### This needs to be IDNA

(define (host-name->byte-vector host)
  (let* ((size (string-length host))
	 (b (make-byte-vector (+ size 1) 0)))
    (do ((i 0 (+ 1 i)))
	((= i size))
      (let ((code (char->integer (string-ref host i))))
	(if (< code 128)
	    (byte-vector-set! b i code)
	    (byte-vector-set! b i #x3f)))) ; ?
    b))

;----------------
; UDP stuff
;
; For UDP messages we need to specify the destination address and receive the
; sender's address.

(define-record-type udp-address :udp-address
  (udp-addresses-are-made-from-c-code)
  udp-address?
  (address  udp-address-address)	; byte vector
  (port     udp-address-port)		; port number
  (hostname real-udp-address-hostname set-udp-address-hostname!))	; string

(define (udp-address-hostname addr)
  (or (real-udp-address-hostname addr)
      (let ((name (get-host-by-address addr)))
	(set-udp-address-hostname! addr name)
	name)))

(define-record-discloser :udp-address
  (lambda (s)
    `(udp-address ,(udp-address-hostname s) ,(udp-address-port s))))

; Export the binding to C for type-checking and making udp-addresses.

(define-exported-binding "s48-udp-address-type" :udp-address)

; Open a UDP socket, returning the two sides.  If a socket port is specified
; it is given to the input half.

(define (open-udp-socket . maybe-port)
  (let* ((input-channel (new-socket #t #t))
	 (output-channel (dup-socket-channel input-channel)))
    (bind-socket input-channel
		 (if (null? maybe-port)
		     #f
		     (car maybe-port)))
    (values (make-socket 'udp-input-socket  input-channel)
	    (make-socket 'udp-output-socket output-channel))))

; Sending and receiving using UPD sockets.

(define (udp-send socket address buffer count)
  (if (not (and (socket? socket)
		(eq? (socket-type socket)
		     'udp-output-socket)))
      (assertion-violation 'udp-send "not a UDP output socket"
			   socket address buffer count))
  (blocking-socket-op socket
		      (lambda (channel retry?)
			(real-udp-send channel address buffer count))))

(define (udp-receive socket buffer)
  (if (not (and (socket? socket)
		(eq? (socket-type socket)
		     'udp-input-socket)))
      (assertion-violation 'udp-receive "not a UDP input socket"
			   socket buffer))
  (let ((got (blocking-socket-op socket
				 (lambda (channel retry?)
				   (real-udp-receive channel buffer)))))
    (values (car got) (cdr got))))

(define (lookup-udp-address name port)
  (real-lookup-udp-address (host-name->byte-vector name)
			   port))

(define (lookup-udp-address name port)
  (real-lookup-udp-address (get-host-by-name name)
			   port))
;----------------
; We need to explicitly close socket channels.

(define (close-socket-input-channel channel)
  (close-socket-half channel #t)
  (close-channel channel))

(define (close-socket-output-channel channel)
  (close-socket-half channel #f)
  (close-channel channel))

;----------------
; The C calls we use.  These are in c/unix/socket.c.

(import-lambda-definition new-socket (upd? input?) "s48_socket")
(import-lambda-definition bind-socket (socket number) "s48_bind")
(import-lambda-definition socket-number (socket) "s48_socket_number")
(import-lambda-definition real-socket-listen (socket) "s48_listen")
(import-lambda-definition real-socket-accept (socket retry?) "s48_accept")
(import-lambda-definition real-socket-connect (socket
					       address
					       port-number
					       retry?)
			  "s48_connect")
(import-lambda-definition dup-socket-channel (socket)
			  "s48_dup_socket_channel")
(import-lambda-definition close-socket-half (socket input?)
			  "s48_close_socket_half")
(import-lambda-definition real-get-host-by-name (name) "s48_get_host_by_name")
(import-lambda-definition get-host-by-name-result (event-uid)
			  "s48_get_host_by_name_result")
(import-lambda-definition real-get-host-by-address (address) "s48_get_host_by_address")
(import-lambda-definition get-host-by-address-result (event-uid)
			  "s48_get_host_by_address_result")
(import-lambda-definition get-host-name () "s48_get_host_name")

; UDP calls
(import-lambda-definition real-udp-send (socket address buffer count)
			  "s48_udp_send")
(import-lambda-definition real-udp-receive (socket buffer)
			  "s48_udp_receive")
(import-lambda-definition real-lookup-udp-address (address port)
			  "s48_lookup_udp_address")


