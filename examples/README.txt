Net::RabbitMQ::PP
-----------------

Net::RabbitMQ::PP::Network -- Lowest layer: basic network operation
  - host
  - port
  - timeout
  - socket
  - write()
  - read()

Net::RabbitMQ::PP::FrameIO -- Mid layer: send and receive layers
  - network
  - _cache
  - write()
  - read()

Net::RabbitMQ::PP::Tx
 - select()
 - commit()
 - rollback()

Net::RabbitMQ::PP -- High layer: talk with RabbitMQ
 - network, frame_io --- lower layers
 - host, port, timeout, vhost, user, password
 - channel -- defaults to "1" unless set
 - connect() --- happens implicitly
 
 - exchange('name') --> returns ::Exchange instance
 - queue('name') --> returns ::Queue instance
 
 - qos()
 - consume()
 - cancel()
 - publish()
 - return()
 - deliver()
 - get()
 - reject()
 - recover()

Net::RabbitMQ::PP::Connection -- eigentlich höchster Layer
 - start()
 - secure()
 - tune()
 - open()
 - close()
 
Net::RabbitMQ::PP::Exchange
 - declare()
 - delete()

Net::RabbitMQ::PP::Queue
 - declare()
 - bind()
 - unbind()
 - purge()
 - delete()

---- AMQP methods:

#### connection:
- start(version-major, version-minor, server-properties, mechanisms, locales)
  -> start-ok(client-properties, mechanism, response, locale)

- secure(challenge)
  -> secure-ok(response)

- tune(channel-max, frame-max, heartbeat)
  -> tune-ok(channel-max, frame-max, heartbeat)

- open(virtual-host)
  -> open-ok()

- close(reply-code, teply-text, class-id, method-id)
  -> close-ok()

#### channel
- open()
  -> open-ok()

- flow(active)
  -> flow-ok(active)

- close(reply-code, teply-text, class-id, method-id)
  ->close-ok()

#### exchange
- declare(exchange, type, passive, durable, no-wait, arguments)
  -> declare-ok()

- delete(exchange, if-unused, no-wait)
  ->delete-ok()

#### queue
- declare(queue, passive, durable, exclusive, auto-delete, no-wait, arguments)
  -> declare-ok()

- bind(queue, exchange, routing-key, no-wait, arguments)
  -> bind-ok()

- unbind(queue, exchange, routing-key, no-wait, arguments)
  -> unbind-ok()

- purge(queue, no-wait)
  -> purge-ok

- delete(queue, if-unused, if-empty, no-wait)
  -> delete-ok(message-count)

#### basic
- qos(prefetch-size, prefetch-count, global)
  -> qos-ok

- consume(queue, consumer-tag, no-local, no-ack, exclusive, no-wait, arguments)
  -> consume-ok(consumer-tag)

- cancel(consumer-tag, no-wait)
  -> cancel-ok(consumer-tag)

- publish

- return

- deliver

- get

- ack

- reject

- requeue

- select

#### tx

- commit

- rollback


Hint:
$ cat share/amqp0-9-1.xml  | egrep '<method|<response|<field' | less
